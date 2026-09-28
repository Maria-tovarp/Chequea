import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/models/user_session.dart';

/// Removes locally cached user content when the user explicitly signs out.
class HomeLocalDataStore {
  const HomeLocalDataStore._();

  static Future<void> clearFor(UserSession session) async {
    final preferences = await SharedPreferences.getInstance();
    final prefixes = [
      'home_draft.${session.username}',
      'sent_messages.${session.country}.${session.username}.',
      'referred_appointments.${session.country}.${session.username}.',
    ];
    final keys = preferences
        .getKeys()
        .where((key) => prefixes.any(key.startsWith))
        .toList();
    await Future.wait(keys.map(preferences.remove));
  }
}
