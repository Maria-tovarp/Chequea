import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InstallSessionGuard {
  InstallSessionGuard._();

  static const _channel = MethodChannel('chequea/install');
  static const _markerKey = 'app.install_marker';

  static Future<bool> isNewInstallation() async {
    String? marker;
    try {
      marker = await _channel.invokeMethod<String>('marker');
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
    if (marker == null || marker.isEmpty) return false;
    final preferences = await SharedPreferences.getInstance();
    final previousMarker = preferences.getString(_markerKey);
    await preferences.setString(_markerKey, marker);
    return previousMarker == null || previousMarker != marker;
  }
}
