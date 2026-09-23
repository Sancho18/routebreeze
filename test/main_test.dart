// Edge case: without GOOGLE_MAPS_API_KEY the app fails fast at startup with
// a message naming env.json (flutter test runs without --dart-define).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/di/injector.dart';
import 'package:routebreeze/core/session/session_state.dart';
import 'package:routebreeze/main.dart' as app;

void main() {
  testWidgets('main() throws a StateError naming env.json before wiring '
      'dependencies or running the app', (tester) async {
    await expectLater(
      app.main(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('env.json'),
        ),
      ),
    );

    expect(getIt.isRegistered<SessionState>(), isFalse);
    expect(find.byType(MaterialApp), findsNothing);
  });
}
