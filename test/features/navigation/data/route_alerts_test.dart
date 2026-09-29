import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/features/navigation/data/route_alerts.dart';

import '../../../helpers/fake_local_notifications.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  RouteAlerts alerts() => PluginRouteAlerts(FlutterLocalNotificationsPlugin());

  List<String> methods(FakeLocalNotifications notifications) => [
    for (final call in notifications.calls) call.method,
  ];

  List<Object?> arguments(FakeLocalNotifications notifications) => [
    for (final call in notifications.calls) call.arguments,
  ];

  const arrivalTitle = 'Você chegou à parada 1';
  const arrivalBody = 'Alameda Santos, 1000. Registre a entrega.';

  group('on Android', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);

    for (final (kind, id, title, body) in const [
      (RouteAlert.arrival, 11, arrivalTitle, arrivalBody),
      (
        RouteAlert.recalculated,
        12,
        'Rota recalculada',
        'Próxima parada 2 · Haddock Lobo, 595',
      ),
      (
        RouteAlert.completed,
        13,
        'Rota concluída',
        '3 entregues · 1 não entregue',
      ),
    ]) {
      test('show posts the ${kind.name} alert as notification $id on the '
          '"Avisos da rota" channel, high importance, with sound', () async {
        final notifications = FakeLocalNotifications.install();

        await alerts().show(kind, title, body);

        expect(notifications.calls.single.method, 'show');
        expect(notifications.calls.single.arguments, {
          'id': id,
          'title': title,
          'body': body,
          'payload': '',
          'platformSpecifics': allOf(
            containsPair('channelId', 'route_alerts'),
            containsPair('channelName', 'Avisos da rota'),
            containsPair('importance', Importance.high.value),
            containsPair('playSound', true),
          ),
        });
      });
    }

    test('clear removes the three alerts, 11, 12 and 13', () async {
      final notifications = FakeLocalNotifications.install();

      await alerts().clear();

      expect(methods(notifications), ['cancel', 'cancel', 'cancel']);
      expect(arguments(notifications), [
        {'id': 11, 'tag': null},
        {'id': 12, 'tag': null},
        {'id': 13, 'tag': null},
      ]);
    });

    test('a failing plugin is ignored: show and clear complete, and clear '
        'still tries every alert', () async {
      final notifications = FakeLocalNotifications.install(
        error: PlatformException(code: 'error'),
      );
      final routeAlerts = alerts();

      await expectLater(
        routeAlerts.show(RouteAlert.arrival, arrivalTitle, arrivalBody),
        completes,
      );
      await expectLater(routeAlerts.clear(), completes);

      expect(methods(notifications), ['show', 'cancel', 'cancel', 'cancel']);
    });
  });

  group('on iOS', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);

    test('show posts the alert with its id, title and body, presented as '
        'set up when the plugin starts', () async {
      final notifications = FakeLocalNotifications.install();

      await alerts().show(RouteAlert.arrival, arrivalTitle, arrivalBody);

      expect(notifications.calls.single.method, 'show');
      expect(notifications.calls.single.arguments, {
        'id': 11,
        'title': arrivalTitle,
        'body': arrivalBody,
        'payload': '',
        'platformSpecifics': null,
      });
    });

    test('clear removes the three alerts, 11, 12 and 13', () async {
      final notifications = FakeLocalNotifications.install();

      await alerts().clear();

      expect(methods(notifications), ['cancel', 'cancel', 'cancel']);
      expect(arguments(notifications), [11, 12, 13]);
    });
  });
}
