import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// The navigation events the driver is alerted of.
enum RouteAlert {
  arrival(11),
  recalculated(12),
  completed(13);

  const RouteAlert(this.id);

  /// Notification id: a newer alert of a kind replaces the one before.
  final int id;
}

/// Event notifications of a navigation.
abstract class RouteAlerts {
  Future<void> show(RouteAlert kind, String title, String body);

  Future<void> clear();
}

/// [RouteAlerts] as local notifications. On Android they use a channel the
/// driver can mute apart from "Navegação"; iOS uses the plugin setup.
class PluginRouteAlerts implements RouteAlerts {
  PluginRouteAlerts(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'route_alerts',
      'Avisos da rota',
      importance: Importance.high,
    ),
  );

  @override
  Future<void> show(RouteAlert kind, String title, String body) async {
    try {
      await _plugin.show(
        id: kind.id,
        title: title,
        body: body,
        notificationDetails: _details,
      );
    } on PlatformException {
      // The navigation goes on without the alert.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await Future.wait([
        for (final kind in RouteAlert.values) _plugin.cancel(id: kind.id),
      ]);
    } on PlatformException {
      // The screen shows the same state.
    }
  }
}
