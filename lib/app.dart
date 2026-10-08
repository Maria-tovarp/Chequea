import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
      fontFamily: GoogleFonts.poppins().fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF009FA4),
        primary: const Color(0xFF009FA4),
        onPrimary: Colors.white,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: Colors.white,
      textTheme: GoogleFonts.poppinsTextTheme(
        const TextTheme(
          headlineSmall: TextStyle(
            color: Color(0xFF24364B),
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
          titleMedium: TextStyle(
            color: Color(0xFF24364B),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          bodyMedium: TextStyle(color: Color(0xFF24364B), fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD5DEF0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD5DEF0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF009FA4), width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF009FA4),
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF10264C),
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        contentTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        insetPadding: EdgeInsets.fromLTRB(16, 12, 16, 46),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        elevation: 14,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
        titleTextStyle: TextStyle(
          color: Color(0xFF10264C),
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: TextStyle(
          color: Color(0xFF435678),
          fontSize: 14,
          height: 1.35,
        ),
      ),
    ),
    home: switch (initialSession) {
      final session? => HomePage(session: session),
      null => const LoginPage(),
    },
  );
}
