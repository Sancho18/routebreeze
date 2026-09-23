import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/config/env.dart';

void main() {
  // `flutter test` runs without --dart-define, so the key is empty here.
  group('Env without GOOGLE_MAPS_API_KEY', () {
    test('isConfigured is false', () {
      expect(Env.googleMapsApiKey, isEmpty);
      expect(Env.isConfigured, isFalse);
    });

    test('ensureConfigured throws a StateError naming env.json', () {
      expect(
        Env.ensureConfigured,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('env.json'),
          ),
        ),
      );
    });
  });
}
