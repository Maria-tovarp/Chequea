import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';
import '../models/login_result.dart';
import '../models/user_session.dart';

class AuthService {
  const AuthService({http.Client? client}) : _client = client;
  final http.Client? _client;

  Future<LoginResult> login({
    required String username,
    required String password,
    required String country,
  }) async {
    final config = AppConfig.forCountry(country);
    final apiKey = config.apiKeyFor(country);
    if (apiKey.isEmpty) {
      return const LoginResult.failure(
        'Falta configurar la clave de acceso de la aplicación.',
      );
    }
    final ownsClient = _client == null;
    final client = _client ?? http.Client();
    try {
      final basic = base64Encode(utf8.encode('$username:$password'));
      final refreshResponse = await client.post(
        Uri.parse('${Uri.parse(config.loginUrl).origin}/api/auth'),
        headers: {
          'Accept': 'application/json',
          'x-api-key': apiKey,
          'Authorization': 'Basic $basic',
        },
      );
      final refresh = _payload(refreshResponse);
      if (refreshResponse.statusCode < 200 ||
          refreshResponse.statusCode >= 300) {
        return LoginResult.failure(_error(refresh));
      }
      final refreshToken = refresh['refresh_token']?.toString();
      if (refreshToken == null || refreshToken.isEmpty) {
        return const LoginResult.failure(
          'El servicio no devolvió una sesión válida.',
        );
      }
      final refreshBranding = brandingNameFromPayload(refresh);
      if (refreshBranding != null) {
        return LoginResult.brandingBlocked(refreshBranding);
      }
      final accessResponse = await client.post(
        Uri.parse('${Uri.parse(config.loginUrl).origin}/api/auth/access'),
        headers: {
          'Accept': 'application/json',
          'x-api-key': apiKey,
          'Authorization': 'Bearer $refreshToken',
        },
      );
      final access = _payload(accessResponse);
      final accessToken = access['access_token']?.toString();
      if (accessResponse.statusCode < 200 ||
          accessResponse.statusCode >= 300 ||
          accessToken == null ||
          accessToken.isEmpty) {
        return LoginResult.failure(_error(access));
      }
      final profileResponse = await client.get(
        Uri.parse(
          '${Uri.parse(config.loginUrl).origin}/api/chequea-api/v1/account/profile',
        ),
        headers: {
          'Accept': 'application/json',
          'x-api-key': apiKey,
          'Authorization': 'Bearer $accessToken',
        },
      );
      final profile = _payload(profileResponse);
      final profileBranding = brandingNameFromPayload(profile);
      if (profileBranding != null) {
        return LoginResult.brandingBlocked(profileBranding);
      }
      return LoginResult.success(
        UserSession(
          username: refresh['username']?.toString() ?? username,
          country: country,
          isChequeandomeAgent: refresh['is_chq_agent'] == true,
          refreshToken: refreshToken,
          accessToken: accessToken,
          fullName: profile['fullname']?.toString(),
          inviteLink: refresh['invite_link']?.toString(),
        ),
      );
    } on Exception {
      return const LoginResult.failure('No se pudo conectar con el servicio.');
    } finally {
      if (ownsClient) client.close();
    }
  }

  Future<UserSession?> refreshSession(UserSession session) async {
    final config = AppConfig.forCountry(session.country);
    final apiKey = config.apiKeyFor(session.country);
    if (apiKey.isEmpty) return null;
    final ownsClient = _client == null;
    final client = _client ?? http.Client();
    try {
      final response = await client.post(
        Uri.parse('${Uri.parse(config.loginUrl).origin}/api/auth/access'),
        headers: {
          'Accept': 'application/json',
          'x-api-key': apiKey,
          'Authorization': 'Bearer ${session.refreshToken}',
        },
      );
      final accessToken = _payload(response)['access_token']?.toString();
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          accessToken == null ||
          accessToken.isEmpty) {
        return null;
      }
      return UserSession(
        username: session.username,
        country: session.country,
        isChequeandomeAgent: session.isChequeandomeAgent,
        refreshToken: session.refreshToken,
        accessToken: accessToken,
        fullName: session.fullName,
        inviteLink: session.inviteLink,
      );
    } on Exception {
      return null;
    } finally {
      if (ownsClient) client.close();
    }
  }

  Future<String?> register({
    required String country,
    required String username,
    required String password,
    required String fullName,
    required String email,
    required String cellphone,
    required bool isDoctor,
    required bool acceptsTerms,
  }) async {
    final config = AppConfig.forCountry(country);
    final apiKey = config.apiKeyFor(country);
    if (apiKey.isEmpty) {
      return 'Falta configurar la clave de acceso de la aplicación.';
    }
    final ownsClient = _client == null;
    final client = _client ?? http.Client();
    try {
      final response = await client.post(
        Uri.parse(
          '${Uri.parse(config.loginUrl).origin}/api/chequea-api/v1/account/register',
        ),
        headers: {'Accept': 'application/json', 'x-api-key': apiKey},
        body: {
          'username': username,
          'password': password,
          'repeat_password': password,
          'fullname': fullName,
          'email': email,
          'cellphone_number': cellphone,
          'is_doctor': isDoctor ? '1' : '0',
          'accepts_terms_conditions': acceptsTerms ? '1' : '0',
        },
      );
      if (response.statusCode >= 200 && response.statusCode < 300) return null;
      final payload = _payload(response);
      final validation = payload['validation_messages'];
      if (validation is Map && validation.isNotEmpty) {
        return validation.values.first.toString();
      }
      return _error(payload);
    } on Exception {
      return 'No se pudo conectar con el servicio.';
    } finally {
      if (ownsClient) client.close();
    }
  }

  Future<Uri?> termsConditionsUrl({required String country}) async {
    final config = AppConfig.forCountry(country);
    final apiKey = config.apiKeyFor(country);
    if (apiKey.isEmpty) return null;
    final ownsClient = _client == null;
    final client = _client ?? http.Client();
    try {
      final response = await client.get(
        Uri.parse(
          '${Uri.parse(config.loginUrl).origin}/api/chequea-api/v1/app_config',
        ),
        headers: {'Accept': 'application/json', 'x-api-key': apiKey},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final value = _payload(response)['terms_conditions_url']?.toString();
      if (value == null || value.trim().isEmpty) return null;
      final uri = Uri.tryParse(value.trim());
      return uri != null && uri.hasScheme ? uri : null;
    } on Exception {
      return null;
    } finally {
      if (ownsClient) client.close();
    }
  }
}

Map<String, dynamic> _payload(http.Response response) {
  try {
    final value = jsonDecode(response.body);
    return value is Map<String, dynamic> ? value : const {};
  } on FormatException {
    return const {};
  }
}

String _error(Map<String, dynamic> body) {
  switch (body['errorcode']) {
    case 'login_not_successful':
      return 'Usuario o contraseña incorrectos.';
    case 'cheq__auth_only_referrer_accounts_allowed':
      return 'Solo se admiten cuentas de referentes.';
    case 'invalid_apikey':
      return 'La clave de acceso de la aplicación no es válida.';
  }
  return body['error']?.toString() ?? 'No fue posible iniciar sesión.';
}

bool hasValidCredentialsResponse(http.Response response) =>
    response.statusCode >= 200 &&
    response.statusCode < 300 &&
    (_payload(response)['refresh_token']?.toString().isNotEmpty ?? false);
bool isChequeandomeAgentResponse(http.Response response) =>
    _payload(response)['is_chq_agent'] == true;
String? brandingLockMessage(http.Response response) =>
    _payload(response)['errorcode']?.toString() ==
        'cheq__auth_only_referrer_accounts_allowed'
    ? 'Solo se admiten cuentas de referentes.'
    : null;

/// Obtiene el título de CHEQUEA Branding en las respuestas autenticadas.
String? brandingNameFromPayload(Map<String, dynamic> payload) {
  const directKeys = [
    'chequea_branding_title',
    'branding_title',
    'brand_title',
  ];
  for (final key in directKeys) {
    final value = _nonEmptyString(payload[key]);
    if (value != null) return value;
  }

  for (final key in const ['chequea_branding', 'branding', 'brand']) {
    final value = payload[key];
    final name = _nonEmptyString(value);
    if (name != null) return name;
    if (value is Map) {
      for (final nameKey in const ['title', 'name', 'fullname']) {
        final nestedName = _nonEmptyString(value[nameKey]);
        if (nestedName != null) return nestedName;
      }
    }
  }
  return null;
}

String? _nonEmptyString(Object? value) {
  if (value is! String) return null;
  final result = value.trim();
  return result.isEmpty ? null : result;
}
