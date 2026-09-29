import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/features/addresses/data/round_trip_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late RoundTripPreference preference;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    preference = RoundTripPreferenceImpl();
  });

  group('RoundTripPreference', () {
    test('load is false when nothing was saved (first use)', () async {
      expect(await preference.load(), isFalse);
    });

    test('save keeps the choice as a bool under round_trip and load reads '
        'it back, on and then off', () async {
      await preference.save(true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('round_trip'), isTrue);
      expect(await preference.load(), isTrue);

      await preference.save(false);

      expect(prefs.getBool('round_trip'), isFalse);
      expect(await preference.load(), isFalse);
    });

    test(
      'a saved choice is read by a new instance, as after a restart',
      () async {
        await preference.save(true);

        expect(await RoundTripPreferenceImpl().load(), isTrue);
      },
    );
  });
}
