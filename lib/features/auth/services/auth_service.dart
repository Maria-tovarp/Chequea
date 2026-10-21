import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';
import '../models/login_result.dart';
import '../models/user_session.dart';
import 'session_expiration.dart';

class AuthService {
  const AuthService({http.Client? client, String? apiKey})
    : _client = client,
      _apiKey = apiKey;
  final http.Client? _client;
  final String? _apiKey;

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
      final refreshResponse = await client
          .post(
            Uri.parse('${Uri.parse(config.loginUrl).origin}/api/auth'),
            headers: {
              'Accept': 'application/json',
              'x-api-key': apiKey,
              'Authorization': 'Basic $basic',
            },
          )
          .timeout(const Duration(seconds: 30));
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
      if (isSessionExpiredResponse(profileResponse) ||
          profileResponse.statusCode < 200 ||
          profileResponse.statusCode >= 300) {
        return LoginResult.failure(_error(profile));
      }
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
          email: profile['email']?.toString(),
          cellphone: profile['cellphone_number']?.toString(),
          inviteLink: refresh['invite_link']?.toString(),
        ),
      );
    } on TimeoutException {
      return const LoginResult.failure(
        'La solicitud tardó demasiado. Inténtalo nuevamente.',
      );
    } on http.ClientException catch (error) {
      if (error.message.contains('Failed host lookup')) {
        return const LoginResult.failure(
          'No se pudo resolver el servidor. Revisa tu conexión a internet.',
        );
      }
      return const LoginResult.failure('No se pudo conectar con el servicio.');
    } on Exception {
      return const LoginResult.failure('No se pudo conectar con el servicio.');
    } finally {
      if (ownsClient) client.close();
    }
  }

  Future<SessionRefreshResult> refreshSession(UserSession session) async {
    final config = AppConfig.forCountry(session.country);
    final apiKey = _apiKey ?? config.apiKeyFor(session.country);
    if (apiKey.isEmpty) return const SessionRefreshResult.unavailable();
    final ownsClient = _client == null;
    final client = _client ?? http.Client();
    try {
      final response = await client
          .post(
            Uri.parse('${Uri.parse(config.loginUrl).origin}/api/auth/access'),
            headers: {
              'Accept': 'application/json',
              'x-api-key': apiKey,
              'Authorization': 'Bearer ${session.refreshToken}',
            },
          )
          .timeout(const Duration(seconds: 30));
      if (isSessionExpiredResponse(response) ||
          const {400, 401, 403, 404}.contains(response.statusCode)) {
        return const SessionRefreshResult.invalidCredentials();
      }
      final accessToken = _payload(response)['access_token']?.toString();
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          accessToken == null ||
          accessToken.isEmpty) {
        return const SessionRefreshResult.unavailable();
      }
      return SessionRefreshResult.refreshed(
        UserSession(
          username: session.username,
          country: session.country,
          isChequeandomeAgent: session.isChequeandomeAgent,
          refreshToken: session.refreshToken,
          accessToken: accessToken,
          fullName: session.fullName,
          email: session.email,
          cellphone: session.cellphone,
          inviteLink: session.inviteLink,
          doctorPhotoPath: session.doctorPhotoPath,
          specialty: session.specialty,
          specialtyTitle: session.specialtyTitle,
          bankAccountNumber: session.bankAccountNumber,
          bankAccountType: session.bankAccountType,
          bankName: session.bankName,
          bankAccountHolder: session.bankAccountHolder,
        ),
      );
    } on Exception {
      return const SessionRefreshResult.unavailable();
    } finally {
      if (ownsClient) client.close();
    }
  }

  Future<String?> forgotPassword({
    required String country,
    required String email,
  }) async {
    final config = AppConfig.forCountry(country);
    final apiKey = config.apiKeyFor(country);
    if (apiKey.isEmpty) {
      return 'Falta configurar la clave de acceso de la aplicación.';
    }
    final ownsClient = _client == null;
    final client = _client ?? http.Client();
    try {
      final request =
          http.MultipartRequest(
              'POST',
              Uri.parse(
                '${Uri.parse(config.loginUrl).origin}/api/chequea-api/v1/account/forgot_password',
              ),
            )
            ..headers.addAll({
              'Accept': 'application/json',
              'x-api-key': apiKey,
            })
            ..fields['email'] = email.trim();
      final response = await http.Response.fromStream(
        await client.send(request).timeout(const Duration(seconds: 30)),
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

  Future<ProfileResult> getProfile(UserSession session) async {
    final config = AppConfig.forCountry(session.country);
    final apiKey = config.apiKeyFor(session.country);
    if (apiKey.isEmpty) {
      return const ProfileResult.failure(
        'Falta configurar la clave de acceso de la aplicación.',
      );
    }
    final ownsClient = _client == null;
    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(
            Uri.parse(
              '${Uri.parse(config.loginUrl).origin}/api/chequea-api/v1/account/profile',
            ),
            headers: {
              'Accept': 'application/json',
              'x-api-key': apiKey,
              'Authorization': 'Bearer ${session.accessToken}',
            },
          )
          .timeout(const Duration(seconds: 30));
      final profile = _payload(response);
      if (isSessionExpiredResponse(response)) {
        return const ProfileResult.invalidCredentials();
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return ProfileResult.failure(_error(profile));
      }
      return ProfileResult.success(_sessionWithProfile(session, profile));
    } on Exception {
      return const ProfileResult.failure(
        'No se pudo conectar con el servicio.',
      );
    } finally {
      if (ownsClient) client.close();
    }
  }

  Future<ProfileResult> updateProfile({
    required UserSession session,
    required String fullName,
    required String email,
    required String cellphone,
    required String medicalSpecialty,
    required String bankAccountNumber,
    required String bankAccountType,
    required String bankAccountBank,
    required String bankAccountHolderName,
    String? profilePicturePath,
    String? password,
  }) async {
    final config = AppConfig.forCountry(session.country);
    final apiKey = config.apiKeyFor(session.country);
    if (apiKey.isEmpty) {
      return const ProfileResult.failure(
        'Falta configurar la clave de acceso de la aplicación.',
      );
    }
    final fields = <String, String>{
      'username': session.username,
      'fullname': fullName.trim(),
      'email': email.trim(),
      'cellphone_number': cellphone.trim(),
      'medical_specialty': medicalSpecialty,
      'bank_account_number': bankAccountNumber.trim(),
      'bank_account_type': bankAccountType,
      'bank_account_bank': bankAccountBank,
      'bank_account_holder_name': bankAccountHolderName.trim(),
    };
    if (password != null && password.isNotEmpty) {
      fields['password'] = password;
      fields['repeat_password'] = password;
    }
    final ownsClient = _client == null;
    final client = _client ?? http.Client();
    try {
      final request =
          http.MultipartRequest(
              'POST',
              Uri.parse(
                '${Uri.parse(config.loginUrl).origin}/api/chequea-api/v1/account/profile/update',
              ),
            )
            ..headers.addAll({
              'Accept': 'application/json',
              'x-api-key': apiKey,
              'Authorization': 'Bearer ${session.accessToken}',
            })
            ..fields.addAll(fields);
      if (profilePicturePath != null && profilePicturePath.isNotEmpty) {
        final picture = File(profilePicturePath);
        if (await picture.exists()) {
          request.files.add(
            await http.MultipartFile.fromPath('profile_picture', picture.path),
          );
        }
      }
      final response = await http.Response.fromStream(
        await client.send(request).timeout(const Duration(seconds: 30)),
      );
      final payload = _payload(response);
      if (isSessionExpiredResponse(response)) {
        return const ProfileResult.invalidCredentials();
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return ProfileResult.failure(_error(payload));
      }
      return ProfileResult.success(
        _sessionWithProfile(
          session,
          payload,
          fallbackFullName: fields['fullname'],
          fallbackEmail: fields['email'],
          fallbackCellphone: fields['cellphone_number'],
          fallbackSpecialty: fields['medical_specialty'],
          fallbackBankAccountNumber: fields['bank_account_number'],
          fallbackBankAccountType: fields['bank_account_type'],
          fallbackBankName: fields['bank_account_bank'],
          fallbackBankAccountHolder: fields['bank_account_holder_name'],
          fallbackProfilePicture: profilePicturePath,
        ),
      );
    } on Exception {
      return const ProfileResult.failure(
        'No se pudo conectar con el servicio.',
      );
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

  Future<ProfileOptionsResult> getProfileOptions(UserSession session) async {
    final config = AppConfig.forCountry(session.country);
    final apiKey = config.apiKeyFor(session.country);
    if (apiKey.isEmpty) return const ProfileOptionsResult.failure();
    final ownsClient = _client == null;
    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(
            Uri.parse(
              '${Uri.parse(config.loginUrl).origin}/api/chequea-api/v1/app_config',
            ),
            headers: {
              'Accept': 'application/json',
              'x-api-key': apiKey,
              'Authorization': 'Bearer ${session.accessToken}',
            },
          )
          .timeout(const Duration(seconds: 30));
      if (isSessionExpiredResponse(response)) {
        return const ProfileOptionsResult.invalidCredentials();
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const ProfileOptionsResult.failure();
      }
      return ProfileOptionsResult.success(
        ProfileOptions.fromJson(_payload(response)),
      );
    } on Exception {
      return const ProfileOptionsResult.failure();
    } finally {
      if (ownsClient) client.close();
    }
  }
}

class SessionRefreshResult {
  const SessionRefreshResult._({this.session, required this.invalid});

  const SessionRefreshResult.refreshed(UserSession session)
    : this._(session: session, invalid: false);

  const SessionRefreshResult.invalidCredentials() : this._(invalid: true);

  const SessionRefreshResult.unavailable() : this._(invalid: false);

  final UserSession? session;
  final bool invalid;
}

class ProfileResult {
  const ProfileResult._({this.session, this.error, this.invalid = false});
  const ProfileResult.success(UserSession session) : this._(session: session);
  const ProfileResult.failure(String error) : this._(error: error);
  const ProfileResult.invalidCredentials() : this._(invalid: true);
  final UserSession? session;
  final String? error;
  final bool invalid;
  bool get isSuccess => session != null;
}

class ProfileOption {
  const ProfileOption({required this.value, required this.title});
  final String value;
  final String title;
}

class ProfileOptions {
  const ProfileOptions({
    required this.medicalSpecialties,
    required this.bankAccountTypes,
    required this.banks,
  });

  final List<ProfileOption> medicalSpecialties;
  final List<ProfileOption> bankAccountTypes;
  final List<ProfileOption> banks;

  factory ProfileOptions.fromJson(Map<String, dynamic> json) => ProfileOptions(
    medicalSpecialties: _options(json['medical_specialties'], key: 'id'),
    bankAccountTypes: _options(json['bank_account_types'], key: 'value'),
    banks: _options(json['banks'], key: 'id'),
  );
}

class ProfileOptionsResult {
  const ProfileOptionsResult._(this.options, {this.invalid = false});
  const ProfileOptionsResult.success(ProfileOptions options) : this._(options);
  const ProfileOptionsResult.failure() : this._(null);
  const ProfileOptionsResult.invalidCredentials() : this._(null, invalid: true);
  final ProfileOptions? options;
  final bool invalid;
  bool get isSuccess => options != null;
}

UserSession _sessionWithProfile(
  UserSession session,
  Map<String, dynamic> profile, {
  String? fallbackFullName,
  String? fallbackEmail,
  String? fallbackCellphone,
  String? fallbackSpecialty,
  String? fallbackSpecialtyTitle,
  String? fallbackBankAccountNumber,
  String? fallbackBankAccountType,
  String? fallbackBankName,
  String? fallbackBankAccountHolder,
  String? fallbackProfilePicture,
}) => UserSession(
  username: session.username,
  country: session.country,
  isChequeandomeAgent: session.isChequeandomeAgent,
  refreshToken: session.refreshToken,
  accessToken: session.accessToken,
  fullName:
      profile['fullname']?.toString() ?? fallbackFullName ?? session.fullName,
  email: profile['email']?.toString() ?? fallbackEmail ?? session.email,
  cellphone:
      profile['cellphone_number']?.toString() ??
      fallbackCellphone ??
      session.cellphone,
  inviteLink: session.inviteLink,
  doctorPhotoPath:
      _profilePictureUrl(profile, session) ??
      fallbackProfilePicture ??
      session.doctorPhotoPath,
  specialty:
      _optionValue(profile['medical_specialty']) ??
      fallbackSpecialty ??
      session.specialty,
  specialtyTitle:
      _optionTitle(profile['medical_specialty']) ??
      fallbackSpecialtyTitle ??
      session.specialtyTitle,
  bankAccountNumber:
      profile['bank_account_number']?.toString() ??
      fallbackBankAccountNumber ??
      session.bankAccountNumber,
  bankAccountType:
      _optionValue(profile['bank_account_type']) ??
      fallbackBankAccountType ??
      session.bankAccountType,
  bankName:
      _optionValue(profile['bank_account_bank']) ??
      fallbackBankName ??
      session.bankName,
  bankAccountHolder:
      profile['bank_account_holder_name']?.toString() ??
      fallbackBankAccountHolder ??
      session.bankAccountHolder,
);

String? _profilePictureUrl(Map<String, dynamic> profile, UserSession session) {
  const keys = ['profile_picture', 'profile_picture_url', 'avatar'];
  for (final key in keys) {
    final value = profile[key];
    final raw = value is Map
        ? (value['url'] ?? value['path'])?.toString().trim()
        : value?.toString().trim();
    if (raw == null || raw.isEmpty) continue;
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.hasScheme) return uri.toString();
    final origin = Uri.parse(
      AppConfig.forCountry(session.country).loginUrl,
    ).origin;
    return Uri.parse('$origin/').resolve(raw).toString();
  }
  return null;
}

List<ProfileOption> _options(dynamic data, {required String key}) {
  if (data is! List) return const [];
  return data
      .whereType<Map>()
      .map((item) {
        final value = item[key]?.toString() ?? '';
        final title = item['title']?.toString() ?? value;
        return ProfileOption(value: value, title: title);
      })
      .where((item) => item.value.isNotEmpty)
      .toList();
}

String? _optionValue(dynamic data) => data is Map
    ? (data['id'] ?? data['value'] ?? data['name'])?.toString()
    : data?.toString();

String? _optionTitle(dynamic data) => data is Map
    ? (data['title'] ?? data['name'] ?? data['label'])?.toString()
    : data?.toString();

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
  final serverMessage = body['error']?.toString().trim() ?? '';
  switch (serverMessage.toLowerCase()) {
    case 'method not allowed':
      return 'No fue posible completar la solicitud. Inténtalo nuevamente más tarde.';
    case 'unauthorized':
    case 'forbidden':
      return 'Tu sesión no tiene permiso para realizar esta acción.';
    case 'not found':
      return 'El servicio solicitado no está disponible en este momento.';
  }
  return serverMessage.isNotEmpty
      ? serverMessage
      : 'No fue posible completar la solicitud.';
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
