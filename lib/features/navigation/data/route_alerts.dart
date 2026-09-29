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

  /// Removes the alerts shown.
  Future<void> clear();
}

/// [RouteAlerts] as local notifications: on Android on the "Avisos da rota"
/// channel (high importance, default sound), which the driver can mute
/// apart from "Navegação"; on iOS as presented by the plugin setup. A
/// failing plugin leaves the navigation as it is.
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
