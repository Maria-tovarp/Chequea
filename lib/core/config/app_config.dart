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

  static const appEnv = String.fromEnvironment(
    'CHEQUEA_APP_ENV',
    defaultValue: 'prepro',
  );

  static const panamaApiKey = String.fromEnvironment('PANAMA_API_KEY');
  static const panamaBaseUrl = String.fromEnvironment('PANAMA_BASE_URL');

  static const panama = CountryOption(
    code: 'panama',
    name: 'Panamá',
    flag: '🇵🇦',
  );

  static const List<CountryOption> countries = [panama];

  static bool isSupportedCountry(String country) {
    final normalized = country.trim().toLowerCase();
    return normalized == 'panamá' || normalized == 'panama';
  }

  static String apiKeyForCountry(String country) {
    return isSupportedCountry(country) ? panamaApiKey : '';
  }

  static String baseUrlForCountry(String country) {
    return isSupportedCountry(country) ? panamaBaseUrl : '';
  }

  static bool get hasApiKey => panamaApiKey.isNotEmpty;

  static CountryConfig forCountry(String country) {
    final baseUrl = baseUrlForCountry(panama.name);
    return CountryConfig(
      country: panama.name,
      baseUrl: baseUrl,
      loginUrl: '$baseUrl/chequea/sesion/login/',
      websiteUrl: '$baseUrl/chequea/sesion/login/',
      apiKeyEnvironment: 'PANAMA_API_KEY',
    );
  }
}

class CountryConfig {
  const CountryConfig({
    required this.country,
    required this.baseUrl,
    required this.loginUrl,
    required this.websiteUrl,
    required this.apiKeyEnvironment,
  });

  final String country;
  final String baseUrl;
  final String loginUrl;
  final String websiteUrl;
  final String apiKeyEnvironment;

  String get apiBaseUrl => '$baseUrl/api';
  String get chequeaApiBaseUrl => '$apiBaseUrl/chequea-api/v1';

  String apiKeyFor(String selectedCountry) =>
      AppConfig.apiKeyForCountry(selectedCountry);
}
