import 'package:flutter/widgets.dart';

import 'app.dart';
import 'features/auth/services/auth_service.dart';
import 'features/auth/services/session_store.dart';
export 'features/auth/services/auth_service.dart'
    show
        brandingLockMessage,
        hasValidCredentialsResponse,
        isChequeandomeAgentResponse;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var session = await SessionStore.load();
  if (session != null) {
    final refreshed = await const AuthService().refreshSession(session);
    if (refreshed != null) {
      session = refreshed;
      await SessionStore.save(session);
    }
  }
  runApp(ChequeaApp(initialSession: session));
}
