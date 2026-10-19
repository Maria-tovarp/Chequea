import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({
    super.key,
    required this.country,
    this.authService = const AuthService(),
  });

  final String country;
  final AuthService authService;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _email = TextEditingController();
  bool _submitted = false;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  bool get _validEmail => _email.text.trim().contains('@');

  Future<void> _send() async {
    setState(() => _submitted = true);
    if (!_validEmail || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final error = await widget.authService.forgotPassword(
      country: widget.country,
      email: _email.text.trim(),
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revisa tu correo'),
        content: const Text(
          'Revisa la bandeja del correo electrónico ingresado. Te enviaremos instrucciones para reestablecer tu contraseña.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF0FAFF),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 34),
                const Center(
                  child: SizedBox(
                    width: 58,
                    height: 58,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFFE5F8F7),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_reset_rounded,
                        size: 34,
                        color: Color(0xFF009FA4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '¿Olvidaste tu contraseña?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF10264C),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Ingresa el correo electrónico asociado a tu cuenta para recibir las instrucciones.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF647194),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  'Correo electrónico',
                  style: TextStyle(
                    color: Color(0xFF10264C),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    hintText: 'Correo electrónico',
                    prefixIcon: const Icon(Icons.email_outlined),
                    errorText: _submitted && !_validEmail
                        ? 'Introduzca un correo electrónico válido.'
                        : null,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 46,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF009FA4),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF009FA4),
                      disabledForegroundColor: Colors.white,
                    ),
                    onPressed: _loading ? null : _send,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    label: const Text('ENVIAR'),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, size: 19),
                    label: const Text('Volver a iniciar sesión'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF009FA4),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
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
}
