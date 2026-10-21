import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'features/auth/models/user_session.dart';
import 'features/auth/pages/login_page.dart';
import 'features/auth/services/auth_service.dart';
import 'features/auth/services/session_store.dart';
import 'features/home/pages/home_page.dart';
import 'features/home/services/home_local_data_store.dart';

class ChequeaApp extends StatefulWidget {
  const ChequeaApp({
    super.key,
    this.initialSession,
    this.showInitialSplash = false,
  });

  final UserSession? initialSession;
  final bool showInitialSplash;

  @override
  State<ChequeaApp> createState() => _ChequeaAppState();
}

class _ChequeaAppState extends State<ChequeaApp> with WidgetsBindingObserver {
  late UserSession? _session = widget.initialSession;
  Timer? _initialSplashTimer;
  Timer? _sessionValidationTimer;
  bool _showInitialSplash = false;
  bool _refreshingSession = false;
  bool _validatingInitialSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final session = _session;
    if (session != null) {
      _validatingInitialSession = true;
      unawaited(_refreshSession(session));
      _sessionValidationTimer = Timer.periodic(const Duration(minutes: 5), (_) {
        final currentSession = _session;
        if (currentSession != null) unawaited(_refreshSession(currentSession));
      });
    }
    if (widget.showInitialSplash) {
      _showInitialSplash = true;
      _initialSplashTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _showInitialSplash = false);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _initialSplashTimer?.cancel();
    _sessionValidationTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final session = _session;
    if (session != null) unawaited(_refreshSession(session));
  }

  Future<void> _refreshSession(UserSession session) async {
    if (_refreshingSession || !_matchesSession(_session, session)) return;
    _refreshingSession = true;
    const authService = AuthService();
    try {
      final result = await authService.refreshSession(session);
      final refreshedSession = result.session;
      UserSession? updatedSession;
      var sessionInvalid = result.invalid;
      if (refreshedSession != null) {
        final profile = await authService.getProfile(refreshedSession);
        sessionInvalid = profile.invalid;
        updatedSession = profile.isSuccess ? profile.session : refreshedSession;
      }
      if (!_matchesSession(_session, session)) return;
      if (sessionInvalid) {
        await _clearSession();
        return;
      }
      if (updatedSession != null) {
        await SessionStore.save(updatedSession);
        if (mounted) setState(() => _session = updatedSession);
      }
    } finally {
      _refreshingSession = false;
      if (_validatingInitialSession && mounted) {
        setState(() => _validatingInitialSession = false);
      }
    }
  }

  void _replaceSession(UserSession session) {
    if (mounted) setState(() => _session = session);
  }

  bool _matchesSession(UserSession? current, UserSession expected) =>
      current != null &&
      current.username == expected.username &&
      current.country == expected.country &&
      current.refreshToken == expected.refreshToken;

  Future<void> _clearSession() async {
    final session = _session;
    if (session != null) await HomeLocalDataStore.clearFor(session);
    await SessionStore.clear();
    if (mounted) setState(() => _session = null);
  }

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
    builder: (context, child) {
      final isAndroid = Theme.of(context).platform == TargetPlatform.android;
      return Stack(
        fit: StackFit.expand,
        children: [
          ?child,
          if (_showInitialSplash)
            ColoredBox(
              key: const ValueKey('initial-splash'),
              color: Colors.white,
              child: Center(
                child: Image.asset(
                  'assets/logo/logo_720px_transparente.png',
                  width: isAndroid ? 122.88 : 240,
                  height: isAndroid ? 85.76 : 167,
                  fit: BoxFit.contain,
                ),
              ),
            ),
        ],
      );
    },
    home: _validatingInitialSession
        ? const Scaffold(backgroundColor: Colors.white)
        : switch (_session) {
            final session? => HomePage(
              session: session,
              onSessionUpdated: _replaceSession,
              onSessionExpired: _clearSession,
            ),
            null => const LoginPage(),
          },
  );
}
