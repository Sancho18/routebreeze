import 'package:shared_preferences/shared_preferences.dart';

/// The last "Voltar ao ponto de partida" choice, kept across routes and
/// restarts.
abstract class RoundTripPreference {
  Future<bool> load();

  Future<void> save(bool value);
}

/// `shared_preferences` implementation: one bool under [key]; a missing key
/// (first use) reads as false.
class RoundTripPreferenceImpl implements RoundTripPreference {
  static const String key = 'round_trip';

  @override
  Future<bool> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? false;
  }

  @override
  Future<void> save(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }
}
