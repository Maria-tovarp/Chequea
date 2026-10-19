import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../../core/config/app_config.dart';
import '../../home/pages/home_page.dart';
import '../../home/services/home_local_data_store.dart';
import '../models/user_session.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';
import '../services/auth_service.dart';
import '../services/session_store.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.authService = const AuthService()});
  final AuthService authService;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final String _country = AppConfig.panama.name;
  bool _submitted = false;
  bool _loading = false;
  bool _showPassword = false;
  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _submitted = true);
    if (_username.text.trim().isEmpty ||
        _password.text.trim().isEmpty ||
        _loading) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final result = await widget.authService.login(
      username: _username.text.trim(),
      password: _password.text,
      country: _country,
    );
    if (!mounted) return;
    if (result.isBrandingBlocked) {
      setState(() => _loading = false);
      final brandingName = result.brandingName;
      if (brandingName == null) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _BrandingAccessDialog(
          brandingName: brandingName,
          onDismissed: () => Navigator.of(dialogContext).pop(),
        ),
      );
      if (!mounted) return;
      _username.clear();
      _password.clear();
      setState(() => _submitted = false);
      return;
    }
    if (!result.isSuccess) {
      setState(() => _loading = false);
      final errorMessage =
          result.errorMessage ?? 'No fue posible iniciar sesiÃ³n.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
      return;
    }
    final loginSession = result.session;
    if (loginSession == null) {
      setState(() => _loading = false);
      return;
    }
    final cachedSession = await SessionStore.load();
    final profile = await widget.authService.getProfile(loginSession);
    var session = profile.isSuccess
        ? profile.session!
        : _withCachedProfile(loginSession, cachedSession);
    session = await _cacheProfilePhoto(session, cachedSession);
    await HomeLocalDataStore.clearFor(session);
    await SessionStore.save(session);
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomePage(session: session)),
    );
  }

  UserSession _withCachedProfile(UserSession session, UserSession? cached) {
    if (cached == null ||
        cached.username != session.username ||
        cached.country != session.country) {
      return session;
    }
    return UserSession(
      username: session.username,
      country: session.country,
      isChequeandomeAgent: session.isChequeandomeAgent,
      refreshToken: session.refreshToken,
      accessToken: session.accessToken,
      fullName: cached.fullName ?? session.fullName,
      email: cached.email ?? session.email,
      cellphone: cached.cellphone ?? session.cellphone,
      inviteLink: session.inviteLink ?? cached.inviteLink,
      doctorPhotoPath: cached.doctorPhotoPath,
      specialty: cached.specialty,
      specialtyTitle: cached.specialtyTitle,
      bankAccountNumber: cached.bankAccountNumber,
      bankAccountType: cached.bankAccountType,
      bankName: cached.bankName,
      bankAccountHolder: cached.bankAccountHolder,
    );
  }

  Future<UserSession> _cacheProfilePhoto(
    UserSession session,
    UserSession? cached,
  ) async {
    final photoUrl = session.doctorPhotoPath?.trim() ?? '';
    if (!photoUrl.startsWith('http://') && !photoUrl.startsWith('https://')) {
      return session;
    }

    final cachedPath =
        cached?.username == session.username &&
            cached?.country == session.country
        ? cached?.doctorPhotoPath
        : null;
    try {
      final response = await http
          .get(Uri.parse(photoUrl))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          response.bodyBytes.isEmpty) {
        throw const HttpException('No fue posible descargar la foto.');
      }
      final directory = await getApplicationDocumentsDirectory();
      final safeUsername = session.username.replaceAll(
        RegExp(r'[^a-zA-Z0-9]'),
        '_',
      );
      final photoFile = File(
        '${directory.path}/doctor-profile-$safeUsername.jpg',
      );
      final temporary = File('${photoFile.path}.tmp');
      await temporary.writeAsBytes(response.bodyBytes, flush: true);
      await temporary.rename(photoFile.path);
      return _withPhotoPath(session, photoFile.path);
    } on Exception {
      if (cachedPath != null && await File(cachedPath).exists()) {
        return _withPhotoPath(session, cachedPath);
      }
      return session;
    }
  }

  UserSession _withPhotoPath(UserSession session, String photoPath) =>
      UserSession(
        username: session.username,
        country: session.country,
        isChequeandomeAgent: session.isChequeandomeAgent,
        refreshToken: session.refreshToken,
        accessToken: session.accessToken,
        fullName: session.fullName,
        email: session.email,
        cellphone: session.cellphone,
        inviteLink: session.inviteLink,
        doctorPhotoPath: photoPath,
        specialty: session.specialty,
        specialtyTitle: session.specialtyTitle,
        bankAccountNumber: session.bankAccountNumber,
        bankAccountType: session.bankAccountType,
        bankName: session.bankName,
        bankAccountHolder: session.bankAccountHolder,
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF0FAFF),
    body: SizedBox.expand(
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SizedBox.expand(
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const _AuthBrand(),
                          const SizedBox(height: 14),
                          const _FixedCountryLabel(),
                          const SizedBox(height: 28),
                          TextField(
                            controller: _username,
                            style: const TextStyle(color: Color(0xFF1A1A1A)),
                            decoration: InputDecoration(
                              hintText: 'Usuario',
                              prefixIcon: const Icon(Icons.person),
                              suffixIconConstraints:
                                  const BoxConstraints.tightFor(
                                    width: 52,
                                    height: 52,
                                  ),
                              error: _submitted && _username.text.trim().isEmpty
                                  ? const _ValidationError()
                                  : null,
                              suffixIcon: _FieldAction(
                                icon: const Icon(Icons.close),
                                onPressed: _username.clear,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            controller: _password,
                            obscureText: !_showPassword,
                            style: const TextStyle(color: Color(0xFF1A1A1A)),
                            decoration: InputDecoration(
                              hintText: 'Contraseña',
                              prefixIcon: const Icon(Icons.lock),
                              suffixIconConstraints:
                                  const BoxConstraints.tightFor(
                                    width: 52,
                                    height: 52,
                                  ),
                              error: _submitted && _password.text.trim().isEmpty
                                  ? const _ValidationError()
                                  : null,
                              suffixIcon: _FieldAction(
                                onPressed: () => setState(
                                  () => _showPassword = !_showPassword,
                                ),
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: OutlinedButton.icon(
                              onPressed: _loading ? null : _login,
                              icon: _loading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.login),
                              label: const Text('ENTRAR'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: const Color(0xFF009FA4),
                                side: const BorderSide(
                                  color: Color(0xFF009FA4),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RegisterPage(country: _country),
                              ),
                            ),
                            child: const Text(
                              'Regístrate aquí',
                              style: TextStyle(
                                color: Color(0xFF009FA4),
                                fontSize: 15,
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFF009FA4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ForgotPasswordPage(country: _country),
                              ),
                            ),
                            child: const Text(
                              '¿Olvidaste tu contraseña?',
                              style: TextStyle(
                                color: Color(0xFF009FA4),
                                fontSize: 15,
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFF009FA4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _AuthBrand extends StatelessWidget {
  const _AuthBrand();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Image.asset(
        'assets/logo/logo_720px_transparente.png',
        width: 230,
        fit: BoxFit.contain,
      ),
    ],
  );
}

class _FixedCountryLabel extends StatelessWidget {
  const _FixedCountryLabel();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'País: Panamá',
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('🇵🇦', style: TextStyle(fontSize: 16)),
        SizedBox(width: 7),
        Text(
          'Panamá',
          style: TextStyle(
            color: Color(0xFF10264C),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _FieldAction extends StatelessWidget {
  const _FieldAction({required this.icon, required this.onPressed});
  final Widget icon;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 52,
    height: 52,
    child: Center(
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          onPressed: onPressed,
          icon: icon,
          color: const Color(0xFF3E4650),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 38, height: 38),
          style: IconButton.styleFrom(
            minimumSize: const Size(38, 38),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    ),
  );
}

class _ValidationError extends StatelessWidget {
  const _ValidationError();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 0, left: 0),
    child: Row(
      children: [
        SizedBox(
          width: 32,
          height: 36,
          child: Center(
            child: Transform.translate(
              offset: const Offset(-8, 0),
              child: Image.asset(
                'assets/images/alert-siren.png',
                width: 36,
                height: 36,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(width: 0),
        const Expanded(
          child: Text(
            'Rellene este campo.',
            style: TextStyle(
              color: Color(0xFFE83D5A),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _BrandingAccessDialog extends StatelessWidget {
  const _BrandingAccessDialog({
    required this.brandingName,
    required this.onDismissed,
  });

  final String brandingName;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.symmetric(horizontal: 30),
    child: Container(
      constraints: const BoxConstraints(maxWidth: 350),
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: Image.asset(
              'assets/images/alert-siren.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'CHEQUEA Branding',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF24364B),
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF47D1B6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'ACCESO PRÓXIMAMENTE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: .4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Próximamente podrás utilizar\nCHEQUEA $brandingName.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF36454F),
              fontSize: 16,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: onDismissed,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF24364B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'ENTENDIDO',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
