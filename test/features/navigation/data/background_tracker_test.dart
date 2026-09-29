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
    // `flutter test` runs no plugin registrant: register the Android
    // implementation the app gets at startup, and run as Android.
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
}
