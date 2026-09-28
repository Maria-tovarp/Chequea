import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_session.dart';

class SessionStore {
  const SessionStore._();

  static const _usernameKey = 'session.username';
  static const _countryKey = 'session.country';
  static const _agentKey = 'session.is_chequeandome_agent';
  static const _refreshTokenKey = 'session.refresh_token';
  static const _accessTokenKey = 'session.access_token';
  static const _fullNameKey = 'session.full_name';
  static const _inviteLinkKey = 'session.invite_link';

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
    return UserSession(
      username: username,
      country: country,
      isChequeandomeAgent: preferences.getBool(_agentKey) ?? false,
      refreshToken: refreshToken,
      accessToken: accessToken,
      fullName: preferences.getString(_fullNameKey),
      inviteLink: preferences.getString(_inviteLinkKey),
    );
  }

  static Future<void> save(UserSession session) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_usernameKey, session.username);
    await preferences.setString(_countryKey, session.country);
    await preferences.setBool(_agentKey, session.isChequeandomeAgent);
    await preferences.setString(_refreshTokenKey, session.refreshToken);
    await preferences.setString(_accessTokenKey, session.accessToken);
    await _setOptional(preferences, _fullNameKey, session.fullName);
    await _setOptional(preferences, _inviteLinkKey, session.inviteLink);
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
      preferences.remove(_inviteLinkKey),
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
