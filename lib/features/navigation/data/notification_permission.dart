import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The permission to post notifications, asked once per install.
abstract class NotificationPermission {
  /// Asks the first time only and completes after the answer, whatever it
  /// is: navigation never waits on a grant.
  Future<void> requestOnce();
}

/// [NotificationPermission] for Android 13+ `POST_NOTIFICATIONS` and iOS
/// alerts and sounds; [key] records that the app asked.
class PluginNotificationPermission implements NotificationPermission {
  PluginNotificationPermission(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const String key = 'notifications_asked';

  @override
  Future<void> requestOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(key)) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, sound: true);
    } on PlatformException {
      // Android refuses a second request while the first one is on screen.
    }
    await prefs.setBool(key, true);
  }
}
