import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/features/navigation/data/notification_permission.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_local_notifications.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  PluginNotificationPermission permission() =>
      PluginNotificationPermission(FlutterLocalNotificationsPlugin());

  Future<bool?> asked() async =>
      (await SharedPreferences.getInstance()).getBool('notifications_asked');

  List<String> methods(FakeLocalNotifications notifications) => [
    for (final call in notifications.calls) call.method,
  ];

  group('on Android', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);

    test('the first call asks for the notification permission '
        '(POST_NOTIFICATIONS) and records under notifications_asked that it '
        'asked', () async {
      final notifications = FakeLocalNotifications.install(
        answers: {'requestNotificationsPermission': true},
      );

      await permission().requestOnce();

      expect(
        notifications.calls.single.method,
        'requestNotificationsPermission',
      );
      expect(notifications.calls.single.arguments, isNull);
      expect(await asked(), isTrue);
    });

    test('a denial completes, so the navigation starts, and a later call '
        'does not ask again', () async {
      final notifications = FakeLocalNotifications.install(
        answers: {'requestNotificationsPermission': false},
      );
      final once = permission();

      await expectLater(once.requestOnce(), completes);
      await once.requestOnce();

      expect(methods(notifications), ['requestNotificationsPermission']);
      expect(await asked(), isTrue);
    });

    test('once asked, as after a restart, it does not ask again', () async {
      SharedPreferences.setMockInitialValues({'notifications_asked': true});
      final notifications = FakeLocalNotifications.install();

      await permission().requestOnce();

      expect(notifications.calls, isEmpty);
    });

    test('a platform error completes too and counts as asked', () async {
      final notifications = FakeLocalNotifications.install(
        error: PlatformException(code: 'permissionRequestInProgress'),
      );
      final once = permission();

      await expectLater(once.requestOnce(), completes);
      await once.requestOnce();

      expect(methods(notifications), ['requestNotificationsPermission']);
    });
  });

  group('on iOS', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);

    test('the first call asks for alerts and sounds, nothing else, and '
        'records that it asked', () async {
      final notifications = FakeLocalNotifications.install(
        answers: {'requestPermissions': true},
      );

      await permission().requestOnce();

      expect(notifications.calls.single.method, 'requestPermissions');
      expect(notifications.calls.single.arguments, {
        'sound': true,
        'alert': true,
        'badge': false,
        'provisional': false,
        'critical': false,
        'carPlay': false,
        'providesAppNotificationSettings': false,
      });
      expect(await asked(), isTrue);
    });

    test('a denial completes and a later call does not ask again', () async {
      final notifications = FakeLocalNotifications.install(
        answers: {'requestPermissions': false},
      );
      final once = permission();

      await expectLater(once.requestOnce(), completes);
      await once.requestOnce();

      expect(methods(notifications), ['requestPermissions']);
      expect(await asked(), isTrue);
    });
  });
}
