import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InstallSessionGuard {
  InstallSessionGuard._();

  static const _versionKey = 'app.session_version';

  static Future<bool> requiresLoginAfterUpdate() async {
    String? version;
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version}+${info.buildNumber}';
    } on Exception {
      return false;
    }
    if (version.isEmpty) return false;
    final preferences = await SharedPreferences.getInstance();
    final previousVersion = preferences.getString(_versionKey);
    await preferences.setString(_versionKey, version);
    return previousVersion != null && previousVersion != version;
  }
}
