import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../services/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    required this.country,
    this.authService = const AuthService(),
  });
  final String country;
  final AuthService authService;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _passwordRepeat = TextEditingController();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _cellphone = TextEditingController();
  bool _isDoctor = false;
  bool _acceptsTerms = false;
  bool _loading = false;
  bool _submitted = false;
  bool _termsConfigLoaded = false;
  Uri? _termsConditionsUrl;

  @override
  void initState() {
    super.initState();
    _loadTermsConditionsUrl();
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _passwordRepeat.dispose();
    _fullName.dispose();
    _email.dispose();
    _cellphone.dispose();
    super.dispose();
  }

  Future<void> _loadTermsConditionsUrl() async {
    final uri = await widget.authService.termsConditionsUrl(
      country: widget.country,
    );
    if (mounted) {
      setState(() {
        _termsConditionsUrl = uri;
        _termsConfigLoaded = true;
      });
    }
  }

  Future<void> _openTermsConditions() async {
    final uri = _termsConditionsUrl;
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No fue posible abrir los términos.')),
      );
    }
  }

  Future<void> _register() async {
    if (!_termsConfigLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cargando términos y condiciones…')),
      );
      return;
    }
    setState(() => _submitted = true);
    final valid =
        _username.text.trim().length >= 3 &&
        RegExp(r'^[a-z0-9_-]{3,50}$').hasMatch(_username.text.trim()) &&
        _password.text.isNotEmpty &&
        _password.text == _passwordRepeat.text &&
        _fullName.text.trim().isNotEmpty &&
        _email.text.contains('@') &&
        _cellphone.text.trim().isNotEmpty &&
        (_termsConditionsUrl == null || _acceptsTerms);
    if (!valid || _loading) return;
    setState(() => _loading = true);
    final error = await widget.authService.register(
      country: widget.country,
      username: _username.text.trim(),
      password: _password.text,
      fullName: _fullName.text.trim(),
      email: _email.text.trim(),
      cellphone: _cellphone.text.trim(),
      isDoctor: _isDoctor,
      acceptsTerms: _termsConditionsUrl == null || _acceptsTerms,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cuenta creada. Ya puedes iniciar sesión.')),
    );
    Navigator.pop(context);
  }

  String? _required(String value) =>
      _submitted && value.trim().isEmpty ? 'Rellene este campo.' : null;

  String? get _usernameError {
    final required = _required(_username.text);
    if (required != null) return required;
    if (_submitted &&
        !RegExp(r'^[a-z0-9_-]{3,50}$').hasMatch(_username.text.trim())) {
      return 'Use entre 3 y 50 minúsculas, números, guiones o guión bajo.';
    }
    return null;
  }

  String? get _emailError {
    final required = _required(_email.text);
    if (required != null) return required;
    if (_submitted && !_email.text.contains('@')) {
      return 'Introduzca un correo electrónico válido.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF47D1B6),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 405),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Image.asset(
                    'assets/images/logo-prod-chequea.png',
                    width: 300,
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    '${_countryOption.flag}  ${_countryOption.name}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 38),
                _label('Cuenta de usuario'),
                TextField(
                  controller: _username,
                  autocorrect: false,
                  style: const TextStyle(color: Color(0xFF1A1A1A)),
                  decoration: InputDecoration(
                    hintText: 'Tu cuenta de usuario',
                    prefixIcon: const Icon(Icons.person),
                    error: _usernameError == null
                        ? null
                        : _ValidationError(_usernameError!),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Utilice sólo letras minúsculas, dígitos, guión y/o guión bajo. Longitud requerida entre 3 y 50 caracteres.',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 22),
                _label('Contraseña'),
                TextField(
                  controller: _password,
                  obscureText: true,
                  style: const TextStyle(color: Color(0xFF1A1A1A)),
                  decoration: InputDecoration(
                    hintText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock),
                    error: _required(_password.text) == null
                        ? null
                        : _ValidationError(_required(_password.text)!),
                  ),
                ),
                const SizedBox(height: 18),
                _label('Repite la contraseña'),
                TextField(
                  controller: _passwordRepeat,
                  obscureText: true,
                  style: const TextStyle(color: Color(0xFF1A1A1A)),
                  decoration: InputDecoration(
                    hintText: 'Repetir contraseña',
                    prefixIcon: const Icon(Icons.lock),
                    error: _passwordRepeatError == null
                        ? null
                        : _ValidationError(_passwordRepeatError!),
                  ),
                ),
                const SizedBox(height: 22),
                _label('Tu nombre completo'),
                TextField(
                  controller: _fullName,
                  style: const TextStyle(color: Color(0xFF1A1A1A)),
                  decoration: InputDecoration(
                    hintText: 'Nombre completo',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    error: _required(_fullName.text) == null
                        ? null
                        : _ValidationError(_required(_fullName.text)!),
                  ),
                ),
                const SizedBox(height: 20),
                _label('¿Eres doctor?'),
                CheckboxListTile(
                  value: _isDoctor,
                  onChanged: (value) =>
                      setState(() => _isDoctor = value ?? false),
                  title: const Text(
                    'Sí, soy doctor',
                    style: TextStyle(color: Colors.white),
                  ),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: Colors.white,
                  checkColor: const Color(0xFF47D1B6),
                ),
                const SizedBox(height: 14),
                _label('Correo electrónico'),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Color(0xFF1A1A1A)),
                  decoration: InputDecoration(
                    hintText: 'Correo electrónico',
                    prefixIcon: const Icon(Icons.email),
                    error: _emailError == null
                        ? null
                        : _ValidationError(_emailError!),
                  ),
                ),
                const SizedBox(height: 20),
                _label('Número celular'),
                TextField(
                  controller: _cellphone,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Color(0xFF1A1A1A)),
                  decoration: InputDecoration(
                    hintText: 'Celular',
                    prefixIcon: const Icon(Icons.phone),
                    error: _required(_cellphone.text) == null
                        ? null
                        : _ValidationError(_required(_cellphone.text)!),
                  ),
                ),
                if (_termsConditionsUrl != null)
                  Row(
                    children: [
                      Checkbox(
                        value: _acceptsTerms,
                        onChanged: (value) =>
                            setState(() => _acceptsTerms = value ?? false),
                        activeColor: Colors.white,
                        checkColor: const Color(0xFF47D1B6),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: _termsConditionsUrl == null
                              ? null
                              : _openTermsConditions,
                          style: TextButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          child: const Text(
                            'Acepto los términos y condiciones',
                            style: TextStyle(
                              color: Colors.white,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                if (_termsConditionsUrl != null && _submitted && !_acceptsTerms)
                  const _ValidationError(
                    'Debe aceptar los términos y condiciones.',
                  ),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _register,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle),
                    label: const Text('CREAR CUENTA'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF24364B),
                      side: const BorderSide(color: Colors.white, width: 2),
                    ),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Iniciar sesión',
                      style: TextStyle(
                        color: Colors.white,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _label(String value) =>
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 17));

  CountryOption get _countryOption => AppConfig.countries.firstWhere(
    (country) => country.name == widget.country,
  );

  String? get _passwordRepeatError =>
      _submitted && _passwordRepeat.text != _password.text
      ? 'Las contraseñas no coinciden.'
      : _required(_passwordRepeat.text);
}

class _ValidationError extends StatelessWidget {
  const _ValidationError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 5, bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
