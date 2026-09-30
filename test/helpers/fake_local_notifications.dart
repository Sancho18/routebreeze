// Fake platform side of `flutter_local_notifications`. The composition root
// initializes the plugin, so every test that runs it needs this installed.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers the plugin channel for one test and records the calls on it.
class FakeLocalNotifications {
  FakeLocalNotifications._();

  static const _channel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );

  /// Every call the plugin made, in order.
  final List<MethodCall> calls = [];

  /// Registers the plugin for the current target platform, as `flutter test`
  /// runs no registrant, so install it after any platform override. Until
  /// the test ends, every call fails with [error] if given; otherwise
  /// [answers] gives a method's result, or a function called on each call.
  static FakeLocalNotifications install({
    PlatformException? error,
    Map<String, Object?> answers = const {},
  }) {
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
      if (answers.containsKey(call.method)) {
        final answer = answers[call.method];
        if (answer is Object? Function()) return answer();
        return answer;
      }
      // `initialize` answers whether it succeeded.
      return call.method == 'initialize' ? true : null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(_channel, null));
    return fake;
  }
}
