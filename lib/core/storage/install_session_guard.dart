import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InstallSessionGuard {
  InstallSessionGuard._();

  static const _installationMarkerKey = 'app.session_installation_marker';
  static const _channel = MethodChannel('chequea.app/installation');

  static Future<bool> requiresLoginAfterInstallOrUpdate() async {
    late final String installationMarker;
    try {
      final info = await PackageInfo.fromPlatform();
      String? nativeMarker;
      try {
        nativeMarker = await _channel.invokeMethod<String>(
          'installationMarker',
        );
      } on MissingPluginException {
        nativeMarker = null;
      }
      installationMarker =
          nativeMarker ?? '${info.version}+${info.buildNumber}';
    } on Exception {
      return false;
    }
    if (installationMarker.isEmpty) return false;
    final preferences = await SharedPreferences.getInstance();
    final previousMarker = preferences.getString(_installationMarkerKey);
    await preferences.setString(_installationMarkerKey, installationMarker);
    return previousMarker != null && previousMarker != installationMarker;
  }
}
