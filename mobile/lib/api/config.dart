class ApiConfig {
  const ApiConfig({required this.baseUrl});

  final String baseUrl;

  static const ApiConfig fromEnv = ApiConfig(
    baseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8000',
    ),
  );
}
