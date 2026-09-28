import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/models/user_session.dart';

class HomeDraftStore {
  const HomeDraftStore._();

  static String _key(UserSession session) => 'home_draft.${session.username}';

  static Future<Map<String, dynamic>?> load(UserSession session) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(session));
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      return value is Map<String, dynamic> ? value : null;
    } on FormatException {
      return null;
    }
  }

  static Future<void> save(
    UserSession session,
    Map<String, dynamic> draft,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key(session), jsonEncode(draft));
  }

  static Future<void> clear(UserSession session) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key(session));
  }
}
