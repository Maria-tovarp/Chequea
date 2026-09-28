import 'package:flutter/material.dart';

import 'features/auth/pages/login_page.dart';
import 'features/auth/models/user_session.dart';
import 'features/home/pages/home_page.dart';

class ChequeaApp extends StatelessWidget {
  const ChequeaApp({super.key, this.initialSession});

  final UserSession? initialSession;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Chequea',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Arial',
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF45CBB7)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    ),
    home: initialSession == null
        ? const LoginPage()
        : HomePage(session: initialSession!),
  );
}
