import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../models/user_session.dart';

class SessionStore {
  const SessionStore._();

  static const _usernameKey = 'session.username';
  static const _countryKey = 'session.country';
  static const _agentKey = 'session.is_chequeandome_agent';
  static const _refreshTokenKey = 'session.refresh_token';
  static const _accessTokenKey = 'session.access_token';
  static const _fullNameKey = 'session.full_name';
  static const _emailKey = 'session.email';
  static const _cellphoneKey = 'session.cellphone';
  static const _inviteLinkKey = 'session.invite_link';
  static const _doctorPhotoPathKey = 'session.doctor_photo_path';
  static const _specialtyKey = 'session.specialty';
  static const _specialtyTitleKey = 'session.specialty_title';
  static const _bankAccountNumberKey = 'session.bank_account_number';
  static const _bankAccountTypeKey = 'session.bank_account_type';
  static const _bankNameKey = 'session.bank_name';
  static const _bankAccountHolderKey = 'session.bank_account_holder';

  static Future<UserSession?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final username = preferences.getString(_usernameKey);
    final country = preferences.getString(_countryKey);
    final refreshToken = preferences.getString(_refreshTokenKey);
    final accessToken = preferences.getString(_accessTokenKey);
    if (username == null ||
        country == null ||
        refreshToken == null ||
        accessToken == null) {
      return null;
    }
    if (!AppConfig.isSupportedCountry(country)) {
      await clear();
      return null;
    }
    return UserSession(
      username: username,
      country: country,
      isChequeandomeAgent: preferences.getBool(_agentKey) ?? false,
      refreshToken: refreshToken,
      accessToken: accessToken,
      fullName: preferences.getString(_fullNameKey),
      email: preferences.getString(_emailKey),
      cellphone: preferences.getString(_cellphoneKey),
      inviteLink: preferences.getString(_inviteLinkKey),
      doctorPhotoPath: preferences.getString(_doctorPhotoPathKey),
      specialty: preferences.getString(_specialtyKey),
      specialtyTitle: preferences.getString(_specialtyTitleKey),
      bankAccountNumber: preferences.getString(_bankAccountNumberKey),
      bankAccountType: preferences.getString(_bankAccountTypeKey),
      bankName: preferences.getString(_bankNameKey),
      bankAccountHolder: preferences.getString(_bankAccountHolderKey),
    );
  }

  static Future<void> save(UserSession session) async {
    if (!AppConfig.isSupportedCountry(session.country)) {
      throw ArgumentError.value(
        session.country,
        'session.country',
        'Panamá es el único país habilitado.',
      );
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_usernameKey, session.username);
    await preferences.setString(_countryKey, session.country);
    await preferences.setBool(_agentKey, session.isChequeandomeAgent);
    await preferences.setString(_refreshTokenKey, session.refreshToken);
    await preferences.setString(_accessTokenKey, session.accessToken);
    await _setOptional(preferences, _fullNameKey, session.fullName);
    await _setOptional(preferences, _emailKey, session.email);
    await _setOptional(preferences, _cellphoneKey, session.cellphone);
    await _setOptional(preferences, _inviteLinkKey, session.inviteLink);
    await _setOptional(
      preferences,
      _doctorPhotoPathKey,
      session.doctorPhotoPath,
    );
    await _setOptional(preferences, _specialtyKey, session.specialty);
    await _setOptional(preferences, _specialtyTitleKey, session.specialtyTitle);
    await _setOptional(
      preferences,
      _bankAccountNumberKey,
      session.bankAccountNumber,
    );
    await _setOptional(
      preferences,
      _bankAccountTypeKey,
      session.bankAccountType,
    );
    await _setOptional(preferences, _bankNameKey, session.bankName);
    await _setOptional(
      preferences,
      _bankAccountHolderKey,
      session.bankAccountHolder,
    );
  }

  static Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.remove(_usernameKey),
      preferences.remove(_countryKey),
      preferences.remove(_agentKey),
      preferences.remove(_refreshTokenKey),
      preferences.remove(_accessTokenKey),
      preferences.remove(_fullNameKey),
      preferences.remove(_emailKey),
      preferences.remove(_cellphoneKey),
      preferences.remove(_inviteLinkKey),
      preferences.remove(_doctorPhotoPathKey),
      preferences.remove(_specialtyKey),
      preferences.remove(_specialtyTitleKey),
      preferences.remove(_bankAccountNumberKey),
      preferences.remove(_bankAccountTypeKey),
      preferences.remove(_bankNameKey),
      preferences.remove(_bankAccountHolderKey),
    ]);
  }

  static Future<void> _setOptional(
    SharedPreferences preferences,
    String key,
    String? value,
  ) => value == null
      ? preferences.remove(key)
      : preferences.setString(key, value);
}
