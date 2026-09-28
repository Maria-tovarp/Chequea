import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../home/pages/home_page.dart';
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
  String _country = 'Panamá';
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
    setState(() => _loading = false);
    if (result.isBrandingBlocked) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _BrandingAccessDialog(
          brandingName: result.brandingName!,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.errorMessage!)));
      return;
    }
    await SessionStore.save(result.session!);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomePage(session: result.session!)),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF47D1B6),
    body: SizedBox.expand(
      child: Container(
        color: const Color(0xFF47D1B6),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 405),
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
                          Image.asset(
                            'assets/images/logo-prod-chequea.png',
                            width: 350,
                          ),
                          const SizedBox(height: 10),
                          _CountryPicker(
                            country: _country,
                            onChanged: (value) =>
                                setState(() => _country = value),
                          ),
                          const SizedBox(height: 54),
                          TextField(
                            controller: _username,
                            style: const TextStyle(color: Color(0xFF1A1A1A)),
                            decoration: InputDecoration(
                              hintText: 'Usuario',
                              prefixIcon: const Icon(Icons.person),
                              error: _submitted && _username.text.trim().isEmpty
                                  ? const _ValidationError()
                                  : null,
                              suffixIcon: _FieldAction(
                                color: const Color(0xFFE83D5A),
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
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
                              error: _submitted && _password.text.trim().isEmpty
                                  ? const _ValidationError()
                                  : null,
                              suffixIcon: _FieldAction(
                                color: const Color(0xFF11C5E8),
                                onPressed: () => setState(
                                  () => _showPassword = !_showPassword,
                                ),
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 36),
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
                              style: ButtonStyle(
                                foregroundColor: const WidgetStatePropertyAll(
                                  Colors.white,
                                ),
                                side: const WidgetStatePropertyAll(
                                  BorderSide(color: Colors.white, width: 2),
                                ),
                                backgroundColor:
                                    WidgetStateProperty.resolveWith((states) {
                                      return _loading ||
                                              states.contains(
                                                WidgetState.pressed,
                                              )
                                          ? const Color(0xFF1097E0)
                                          : Colors.transparent;
                                    }),
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
                                color: Colors.white,
                                fontSize: 15,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.white,
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

class _CountryPicker extends StatelessWidget {
  const _CountryPicker({required this.country, required this.onChanged});
  final String country;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F1F1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: country,
        isDense: true,
        dropdownColor: const Color(0xFFF1F1F1),
        icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF555555)),
        style: const TextStyle(
          color: Color(0xFF1A1A1A),
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        items: AppConfig.countries
            .map(
              (item) => DropdownMenuItem(
                value: item.name,
                child: Text('${item.flag}  ${item.name}'),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    ),
  );
}

class _FieldAction extends StatelessWidget {
  const _FieldAction({
    required this.color,
    required this.icon,
    required this.onPressed,
  });
  final Color color;
  final Widget icon;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: color,
      borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
    ),
    child: IconButton(onPressed: onPressed, icon: icon),
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
        const Text(
          'Rellene este campo.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
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
