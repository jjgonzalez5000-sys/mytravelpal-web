class ApiConfig {
  const ApiConfig({required this.baseUrl, this.apiKey});

  final String baseUrl;

  /// Static API key baked in at build time via
  /// `--dart-define=API_KEY=…`. When set, every outgoing request adds
  /// `X-MyTravelPal-Api-Key`. Empty → no header, matches local dev
  /// where the backend gate is disabled.
  final String? apiKey;

  static const ApiConfig fromEnv = ApiConfig(
    baseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8000',
    ),
    apiKey: String.fromEnvironment('API_KEY', defaultValue: ''),
  );
}
