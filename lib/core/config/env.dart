/// Build-time configuration from `--dart-define-from-file=env.json`; the file
/// is gitignored, so the key stays out of source control.
abstract final class Env {
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
  );

  static bool get isConfigured => googleMapsApiKey.isNotEmpty;

  /// Fails fast at startup when the key is missing.
  static void ensureConfigured() {
    if (isConfigured) return;
    throw StateError(
      'GOOGLE_MAPS_API_KEY ausente. Crie env.json a partir de env.example.json '
      '(ou rode tool/set_api_key.sh <CHAVE>) e compile com '
      '--dart-define-from-file=env.json.',
    );
  }
}
