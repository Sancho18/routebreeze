import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/features/navigation/data/background_tracker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The channel `flutter_local_notifications` talks to the platform through.
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  setUp(() {
    // `flutter test` runs no plugin registrant, so register the Android one.
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  group('ForegroundServiceTracker', () {
    test('start runs a location foreground service, not sticky, with the '
        'ongoing "RouteBreeze · Acompanhando sua rota" notification', () async {
      await ForegroundServiceTracker(FlutterLocalNotificationsPlugin()).start();

      expect(calls.single.method, 'startForegroundService');
      expect(calls.single.arguments, {
        'notificationData': {
          'id': 1,
          'title': 'RouteBreeze',
          'body': 'Acompanhando sua rota',
          'payload': '',
          'platformSpecifics': allOf(
            containsPair('channelId', 'navigation'),
            containsPair('channelName', 'Navegação'),
            containsPair('importance', Importance.low.value),
            containsPair('ongoing', true),
            containsPair('onlyAlertOnce', true),
            containsPair('icon', 'ic_stat_routebreeze'),
          ),
        },
        'startType': AndroidServiceStartType.startNotSticky.index,
        'foregroundServiceTypes': [
          AndroidServiceForegroundType.foregroundServiceTypeLocation.value,
        ],
      });
    });

    test('stop stops the foreground service and so its notification', () async {
      await ForegroundServiceTracker(FlutterLocalNotificationsPlugin()).stop();

      expect(calls.single.method, 'stopForegroundService');
    });

    test('a platform error on start is swallowed, so the navigation goes '
        'on', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        throw PlatformException(code: 'error');
      });

      await expectLater(
        ForegroundServiceTracker(FlutterLocalNotificationsPlugin()).start(),
        completes,
      );
      expect(calls.single.method, 'startForegroundService');
    });

    group('update', () {
      const title = 'Próxima parada 2 · Rua Augusta, 500';
      const body = '1,2 km · 4 min · chegada às 14:32';

      void failEveryCall() =>
          messenger.setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            throw PlatformException(code: 'error');
          });

      List<String> methods() => [for (final call in calls) call.method];

      test('shows the texts on the running service\'s notification: id 1 '
          'again, same channel, start type and service type as start, '
          'without sound or vibration and alerting only once', () async {
        final tracker = ForegroundServiceTracker(
          FlutterLocalNotificationsPlugin(),
        );
        await tracker.start();

        await tracker.update(title, body);

        expect(methods(), ['startForegroundService', 'startForegroundService']);
        expect(calls.last.arguments, {
          'notificationData': {
            'id': 1,
            'title': title,
            'body': body,
            'payload': '',
            'platformSpecifics': allOf([
              containsPair('channelId', 'navigation'),
              containsPair('channelName', 'Navegação'),
              containsPair('importance', Importance.low.value),
              containsPair('ongoing', true),
              containsPair('onlyAlertOnce', true),
              containsPair('icon', 'ic_stat_routebreeze'),
              containsPair('playSound', false),
              containsPair('enableVibration', false),
            ]),
          },
          'startType': AndroidServiceStartType.startNotSticky.index,
          'foregroundServiceTypes': [
            AndroidServiceForegroundType.foregroundServiceTypeLocation.value,
          ],
        });
      });

      test('asked while the start is on its way, it is shown once the '
          'service runs', () async {
        final tracker = ForegroundServiceTracker(
          FlutterLocalNotificationsPlugin(),
        );

        final starting = tracker.start();
        final updating = tracker.update(title, body);
        await Future.wait([starting, updating]);

        expect(
          [
            for (final call in calls)
              (call.arguments as Map)['notificationData']['title'],
          ],
          ['RouteBreeze', title],
        );
      });

      test('before start it sends nothing, since the call would start the '
          'service', () async {
        await ForegroundServiceTracker(FlutterLocalNotificationsPlugin())
            .update(title, body);

        expect(calls, isEmpty);
      });

      test('after stop it sends nothing, also when the stop comes while it '
          'waits for the start', () async {
        final tracker = ForegroundServiceTracker(
          FlutterLocalNotificationsPlugin(),
        );

        final starting = tracker.start();
        final updating = tracker.update(title, body);
        await tracker.stop();
        await Future.wait([starting, updating]);
        await tracker.update(title, body);

        expect(methods(), ['startForegroundService', 'stopForegroundService']);
      });

      test('after a failed start it sends nothing, also when asked while '
          'that start was on its way', () async {
        failEveryCall();
        final tracker = ForegroundServiceTracker(
          FlutterLocalNotificationsPlugin(),
        );

        final starting = tracker.start();
        final updating = tracker.update(title, body);
        await Future.wait([starting, updating]);
        await tracker.update(title, body);

        expect(methods(), ['startForegroundService']);
      });

      test('a platform error on update is swallowed, and the next update '
          'still goes', () async {
        final tracker = ForegroundServiceTracker(
          FlutterLocalNotificationsPlugin(),
        );
        await tracker.start();
        failEveryCall();

        await expectLater(tracker.update(title, body), completes);
        expect(methods(), ['startForegroundService', 'startForegroundService']);

        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
        await tracker.update(title, 'Você chegou');

        expect(methods(), [
          'startForegroundService',
          'startForegroundService',
          'startForegroundService',
        ]);
        expect(
          (calls.last.arguments as Map)['notificationData'],
          allOf(
            containsPair('title', title),
            containsPair('body', 'Você chegou'),
          ),
        );
      });
    });
  });

  test(
    'NoopBackgroundTracker starts and stops nothing on the platform',
    () async {
      final tracker = NoopBackgroundTracker();

      await tracker.start();
      await tracker.stop();

      expect(calls, isEmpty);
    },
  );

  test('NoopBackgroundTracker ignores updates', () async {
    final tracker = NoopBackgroundTracker();
    await tracker.start();

    await tracker.update('Próxima parada 2 · Rua Augusta, 500', 'Você chegou');

    expect(calls, isEmpty);
  });
}
