class CountryOption {
  const CountryOption({
    required this.code,
    required this.name,
    required this.flag,
  });

  final String code;
  final String name;
  final String flag;
}

class AppConfig {
  const AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'CHEQUEA_API_BASE_URL',
    defaultValue: 'https://api.example.com',
  );

  static const apiKey = String.fromEnvironment('CHEQUEA_API_KEY');

  static const panama = CountryOption(
    code: 'panama',
    name: 'Panamá',
    flag: '🇵🇦',
  );

  static String apiKeyForCountry(String country) {
    return const String.fromEnvironment('PANAMA_API_KEY');
  }

  static const environment = String.fromEnvironment(
    'CHEQUEA_APP_ENV',
    defaultValue: 'development',
  );

  static const List<CountryOption> countries = [panama];

  static bool isSupportedCountry(String country) {
    final normalized = country.trim().toLowerCase();
    return normalized == 'panamá' || normalized == 'panama';
  }

  static bool get hasApiKey => apiKey.isNotEmpty;

  static CountryConfig forCountry(String country) {
    return const CountryConfig(
      country: 'Panamá',
      loginUrl: 'https://chequeandome.com/chequea/sesion/login/',
      websiteUrl: 'https://chequeandome.com/chequea/sesion/login/',
      apiKeyEnvironment: 'PANAMA_API_KEY',
    );
  }
}

class CountryConfig {
  const CountryConfig({
    required this.country,
    required this.loginUrl,
    required this.websiteUrl,
    required this.apiKeyEnvironment,
  });

  final String country;
  final String loginUrl;
  final String websiteUrl;
  final String apiKeyEnvironment;

  String apiKeyFor(String selectedCountry) =>
      AppConfig.apiKeyForCountry(selectedCountry);
}
