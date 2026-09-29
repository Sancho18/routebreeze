// Test double for the platform side of `flutter_local_notifications`: the
// composition root initializes the plugin, so every test that runs it needs
// the plugin's channel answered.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers `dexterous.com/flutter/local_notifications` for one test and
/// records the calls the plugin made on it.
class FakeLocalNotifications {
  FakeLocalNotifications._();

  static const _channel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );

  /// Every call the plugin made, in order.
  final List<MethodCall> calls = [];

  /// Registers the plugin's implementation for the current target platform
  /// (`flutter test` runs no plugin registrant), so install it after any
  /// platform override. The channel is answered until the test ends; with
  /// [error], every call fails with it.
  static FakeLocalNotifications install({PlatformException? error}) {
    final fake = FakeLocalNotifications._();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      IOSFlutterLocalNotificationsPlugin.registerWith();
    } else {
      AndroidFlutterLocalNotificationsPlugin.registerWith();
    }
    final messenger =
        TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      fake.calls.add(call);
      if (error != null) throw error;
      // `initialize` answers whether it succeeded.
      return call.method == 'initialize' ? true : null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(_channel, null));
    return fake;
  }
}
