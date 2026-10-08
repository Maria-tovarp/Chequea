import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/storage/install_session_guard.dart';
import 'features/auth/services/auth_service.dart';
import 'features/auth/services/session_store.dart';
export 'features/auth/services/auth_service.dart'
    show
        brandingLockMessage,
        hasValidCredentialsResponse,
        isChequeandomeAgentResponse;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Color(0xFF24364B),
      systemNavigationBarDividerColor: Color(0xFF24364B),
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  if (await InstallSessionGuard.isNewInstallation()) {
    await SessionStore.clear();
  }
  var session = await SessionStore.load();
  if (session != null) {
    final refreshed = await const AuthService().refreshSession(session);
    if (refreshed != null) {
      session = refreshed;
      await SessionStore.save(session);
    } else {
      await SessionStore.clear();
      session = null;
    }
  }
  runApp(ChequeaApp(initialSession: session));
}
