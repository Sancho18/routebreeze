import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Keeps the app allowed to track the route while it is in background.
abstract class BackgroundTracker {
  Future<void> start();

  /// Shows [title] and [body] on the tracking notification while tracking
  /// runs.
  Future<void> update(String title, String body);

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

  /// [_details] that update without sound or vibration.
  static const _updateDetails = AndroidNotificationDetails(
    'navigation',
    'Navegação',
    importance: Importance.low,
    ongoing: true,
    onlyAlertOnce: true,
    icon: 'ic_stat_routebreeze',
    playSound: false,
    enableVibration: false,
  );

  /// Whether the last [start] got the service running; null before it and
  /// after [stop].
  Future<bool>? _running;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> start() async {
    await (_running = _startService(
      'RouteBreeze',
      'Acompanhando sua rota',
      _details,
    ));
  }

  /// Waits for a start on its way. Sends nothing before [start], after
  /// [stop] or a failed start: the call would start the service again.
  @override
  Future<void> update(String title, String body) async {
    final running = _running;
    if (running == null || !await running || running != _running) return;
    await _startService(title, body, _updateDetails);
  }

  @override
  Future<void> stop() async {
    _running = null;
    await _android?.stopForegroundService();
  }

  /// Starts the service, or updates its notification while it runs; false
  /// when the platform refuses.
  Future<bool> _startService(
    String title,
    String body,
    AndroidNotificationDetails details,
  ) async {
    try {
      await _android?.startForegroundService(
        id: 1,
        title: title,
        body: body,
        notificationDetails: details,
        startType: AndroidServiceStartType.startNotSticky,
        foregroundServiceTypes: {
          AndroidServiceForegroundType.foregroundServiceTypeLocation,
        },
      );
      return true;
    } on PlatformException {
      // A refused start leaves tracking in foreground as before; a refused
      // update, the texts shown.
      return false;
    }
  }
}

/// [BackgroundTracker] for platforms that keep tracking without a service
/// (iOS: background location updates).
class NoopBackgroundTracker implements BackgroundTracker {
  @override
  Future<void> start() async {}

  @override
  Future<void> update(String title, String body) async {}

  @override
  Future<void> stop() async {}
}
