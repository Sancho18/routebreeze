import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Keeps the app allowed to track the route while it is in background.
abstract class BackgroundTracker {
  Future<void> start();

  Future<void> stop();
}

/// [BackgroundTracker] over an Android foreground service of type location
/// (`flutter_local_notifications`), shown as the ongoing navigation
/// notification. When the service cannot start, tracking stays in
/// foreground and the navigation goes on.
class ForegroundServiceTracker implements BackgroundTracker {
  ForegroundServiceTracker(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const _details = AndroidNotificationDetails(
    'navigation',
    'Navegação',
    importance: Importance.low,
    ongoing: true,
    onlyAlertOnce: true,
    icon: 'ic_stat_routebreeze',
  );

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> start() async {
    try {
      await _android?.startForegroundService(
        id: 1,
        title: 'RouteBreeze',
        body: 'Acompanhando sua rota',
        notificationDetails: _details,
        startType: AndroidServiceStartType.startNotSticky,
        foregroundServiceTypes: {
          AndroidServiceForegroundType.foregroundServiceTypeLocation,
        },
      );
    } on PlatformException {
      // Tracking pauses in background as before.
    }
  }

  @override
  Future<void> stop() async {
    await _android?.stopForegroundService();
  }
}

/// [BackgroundTracker] for platforms that keep tracking without a service
/// (iOS: background location updates).
class NoopBackgroundTracker implements BackgroundTracker {
  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}
