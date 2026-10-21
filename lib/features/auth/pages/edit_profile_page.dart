import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../home/widgets/app_notice_dialog.dart';
import '../../home/services/home_local_data_store.dart';
import '../models/user_session.dart';
import '../services/auth_service.dart';
import '../services/session_store.dart';
import 'login_page.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.session});
  final UserSession session;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _cellphone = TextEditingController();
  final _password = TextEditingController();
  final _repeatPassword = TextEditingController();
  final _bankAccountNumber = TextEditingController();
  final _bankAccountHolder = TextEditingController();
  final _auth = const AuthService();
  final _imagePicker = ImagePicker();
  UserSession? _session;
  String? _photoPath;
  String? _specialty;
  String? _specialtyTitle;
  String? _bankAccountType;
  String? _bankName;
  List<ProfileOption> _medicalSpecialties = const [];
  List<ProfileOption> _bankAccountTypes = const [];
  List<ProfileOption> _banks = const [];
  bool _saving = false;
  bool _pickingPhoto = false;
  bool _submitted = false;
  bool _loadingProfile = true;
  int _profileLoadVersion = 0;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _fullName.text = widget.session.fullName ?? '';
    _email.text = widget.session.email ?? '';
    _cellphone.text = widget.session.cellphone ?? '';
    _photoPath = widget.session.doctorPhotoPath;
    _specialty = widget.session.specialty;
    _specialtyTitle = widget.session.specialtyTitle;
    _bankAccountNumber.text = widget.session.bankAccountNumber ?? '';
    _bankAccountType = widget.session.bankAccountType;
    _bankName = widget.session.bankName;
    _bankAccountHolder.text = widget.session.bankAccountHolder ?? '';
    _initialize();
  }

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _cellphone.dispose();
    _password.dispose();
    _repeatPassword.dispose();
    _bankAccountNumber.dispose();
    _bankAccountHolder.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        // Keep the decoded image small enough for modest Android devices.
        maxWidth: 720,
        maxHeight: 720,
        imageQuality: 72,
      );
      if (photo != null) await _storePhoto(photo);
    } on Exception {
      if (mounted) _showPhotoError();
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Future<void> _recoverLostPhoto() async {
    try {
      final response = await _imagePicker.retrieveLostData();
      if (response.isEmpty || response.file == null) return;
      await _storePhoto(response.file!);
    } on Exception {
      // The picker recovery is best-effort; the form must remain usable.
    }
  }

  Future<void> _storePhoto(XFile photo) async {
    try {
      _profileLoadVersion++;
      if (await photo.length() == 0) {
        throw FileSystemException('La imagen seleccionada está vacía.');
      }
      final directory = await getApplicationDocumentsDirectory();
      final originalPath = photo.path;
      final dotIndex = originalPath.lastIndexOf('.');
      final extension = dotIndex > -1
          ? originalPath.substring(dotIndex).toLowerCase()
          : '.jpg';
      final timestamp = DateTime.now().microsecondsSinceEpoch;
      final destination = File(
        '${directory.path}/doctor-profile-$timestamp$extension',
      );
      final temporary = File('${destination.path}.tmp');

      // Copy first and only expose a complete file to Image.file. This avoids
      // a decoder seeing a partially written file when Android returns here.
      await File(originalPath).copy(temporary.path);
      await temporary.rename(destination.path);

      if (!mounted) return;
      setState(() => _photoPath = destination.path);
    } on Exception {
      if (mounted) _showPhotoError();
    }
  }

  void _showPhotoError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No fue posible cargar la foto. Intenta con otra imagen.',
        ),
      ),
    );
  }

  Future<void> _initialize() async {
    await _recoverLostPhoto();
    await _load();
  }

  Future<void> _load() async {
    final loadVersion = _profileLoadVersion;
    final results = await Future.wait<Object>([
      _auth.getProfile(widget.session),
      _auth.getProfileOptions(widget.session),
    ]);
    if (!mounted) return;
    if (loadVersion != _profileLoadVersion) {
      setState(() => _loadingProfile = false);
      return;
    }
    final profileResult = results[0] as ProfileResult;
    final optionsResult = results[1] as ProfileOptionsResult;
    if (profileResult.invalid || optionsResult.invalid) {
      await _logout();
      return;
    }
    if (profileResult.isSuccess) {
      _applyProfile(profileResult.session!);
    }
    if (optionsResult.isSuccess) {
      final options = optionsResult.options!;
      _medicalSpecialties = options.medicalSpecialties;
      _bankAccountTypes = options.bankAccountTypes;
      _banks = options.banks;
      _specialty = _normalizeOption(_specialty, _medicalSpecialties);
      _specialtyTitle = _optionTitleFor(_specialty, _medicalSpecialties);
      _bankAccountType = _normalizeOption(_bankAccountType, _bankAccountTypes);
      _bankName = _normalizeOption(_bankName, _banks);
    }
    if (mounted) setState(() => _loadingProfile = false);
  }

  void _applyProfile(UserSession session) {
    _session = session;
    _fullName.text = session.fullName ?? '';
    _email.text = session.email ?? '';
    _cellphone.text = session.cellphone ?? '';
    _photoPath = session.doctorPhotoPath;
    _specialty = session.specialty;
    _specialtyTitle = session.specialtyTitle;
    _bankAccountNumber.text = session.bankAccountNumber ?? '';
    _bankAccountType = session.bankAccountType;
    _bankName = session.bankName;
    _bankAccountHolder.text = session.bankAccountHolder ?? '';
  }

  String? _normalizeOption(String? value, List<ProfileOption> options) {
    if (value == null || value.isEmpty) return null;
    for (final option in options) {
      if (option.value == value || option.title == value) return option.value;
    }
    return value;
  }

  String? _optionTitleFor(String? value, List<ProfileOption> options) {
    for (final option in options) {
      if (option.value == value) return option.title;
    }
    return _specialtyTitle;
  }

  String? _required(String value, String label) =>
      _submitted && value.trim().isEmpty ? _requiredMessage(label) : null;

  String _requiredMessage(String label) => switch (label) {
    'Nombre completo' => 'Ingresa tu nombre completo.',
    'Nombre del dueño de la cuenta' =>
      'Ingresa el nombre del dueño de la cuenta.',
    _ => 'Completa este campo.',
  };

  String? get _emailError {
    if (!_submitted) return null;
    if (_email.text.trim().isEmpty) return 'Ingresa tu correo electrónico.';
    return _email.text.contains('@')
        ? null
        : 'Ingresa un correo electrónico válido.';
  }

  String? _bankAccountNumberError(String value) {
    if (!_submitted) return null;
    final accountNumber = value.trim();
    if (accountNumber.isEmpty) {
      return 'Ingresa el número de cuenta bancaria.';
    }
    if (accountNumber.length < 6) {
      return 'Ingresa un número de cuenta válido.';
    }
    return null;
  }

  String? _requiredSelection(String? value, String label) {
    if (!_submitted || (value != null && value.isNotEmpty)) return null;
    return switch (label) {
      'Especialidad' => 'Selecciona tu especialidad.',
      'Tipo de cuenta' => 'Selecciona el tipo de cuenta.',
      'Banco' => 'Selecciona el banco.',
      _ => 'Selecciona una opción.',
    };
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    final hasPassword = _password.text.isNotEmpty;
    final valid =
        _fullName.text.trim().isNotEmpty &&
        _email.text.trim().contains('@') &&
        _cellphone.text.trim().isNotEmpty &&
        (_specialty?.isNotEmpty ?? false) &&
        _bankAccountNumberError(_bankAccountNumber.text) == null &&
        (_bankAccountType?.isNotEmpty ?? false) &&
        (_bankName?.isNotEmpty ?? false) &&
        _bankAccountHolder.text.trim().isNotEmpty &&
        (!hasPassword || _password.text == _repeatPassword.text);
    if (!valid || _saving || _session == null) {
      if (!_saving && _session != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              backgroundColor: const Color(0xFF10264C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              content: const Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFFFC766),
                    size: 21,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Completa los campos marcados con (*)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
      }
      return;
    }
    // Invalidates any profile request still running from the initial screen load.
    _profileLoadVersion++;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final result = await _auth.updateProfile(
      session: _session!,
      fullName: _fullName.text,
      email: _email.text,
      cellphone: _cellphone.text,
      medicalSpecialty: _specialty!,
      bankAccountNumber: _bankAccountNumber.text,
      bankAccountType: _bankAccountType!,
      bankAccountBank: _bankName!,
      bankAccountHolderName: _bankAccountHolder.text,
      profilePicturePath: _isLocalPhoto ? _photoPath : null,
      password: hasPassword ? _password.text : null,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.invalid) {
      await _logout();
      return;
    }
    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'No fue posible actualizar el perfil.'),
        ),
      );
      return;
    }
    final updatedSession = _withLocalProfile(result.session!);
    await SessionStore.save(updatedSession);
    if (!mounted) return;
    Navigator.of(context).pop(updatedSession);
  }

  UserSession _withLocalProfile(UserSession session) => UserSession(
    username: session.username,
    country: session.country,
    isChequeandomeAgent: session.isChequeandomeAgent,
    refreshToken: session.refreshToken,
    accessToken: session.accessToken,
    fullName: _fullName.text.trim(),
    email: _email.text.trim(),
    cellphone: _cellphone.text.trim(),
    inviteLink: session.inviteLink,
    doctorPhotoPath: _photoPath,
    specialty: _specialty,
    specialtyTitle: _specialtyTitle,
    bankAccountNumber: _bankAccountNumber.text.trim(),
    bankAccountType: _bankAccountType,
    bankName: _bankName,
    bankAccountHolder: _bankAccountHolder.text.trim(),
  );

  bool get _isLocalPhoto {
    final photoPath = _photoPath;
    if (photoPath == null || photoPath.isEmpty) return false;
    return !(Uri.tryParse(photoPath)?.hasScheme ?? false);
  }

  Future<void> _logout() async {
    final session = _session;
    if (session != null) await HomeLocalDataStore.clearFor(session);
    await SessionStore.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => PopScope<UserSession>(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) {
        Navigator.of(context).pop();
      }
    },
    child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF10264C),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 56,
        leadingWidth: 36,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          'Mi perfil',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        actions: [const HeaderNoticeActions()],
      ),
      body: SafeArea(
        top: false,
        child: _loadingProfile
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF009FA4)),
              )
            : Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ProfileCard(
                          icon: Icons.person_outline_rounded,
                          title: 'Información personal',
                          subtitle: 'Datos de la cuenta',
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  InkWell(
                                    onTap: _pickingPhoto ? null : _pickPhoto,
                                    borderRadius: BorderRadius.circular(38),
                                    child: Container(
                                      width: 108,
                                      height: 108,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFE5F8F7),
                                        shape: BoxShape.circle,
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          if (_photoPath == null)
                                            const Icon(
                                              Icons.add_a_photo_outlined,
                                              color: Color(0xFF009FA4),
                                            )
                                          else if (!_isLocalPhoto)
                                            Image.network(
                                              _photoPath!,
                                              fit: BoxFit.cover,
                                              cacheWidth: 152,
                                              cacheHeight: 152,
                                              errorBuilder: (_, _, _) =>
                                                  const Icon(
                                                    Icons.add_a_photo_outlined,
                                                    color: Color(0xFF009FA4),
                                                  ),
                                            )
                                          else
                                            Image.file(
                                              File(_photoPath!),
                                              fit: BoxFit.cover,
                                              cacheWidth: 152,
                                              cacheHeight: 152,
                                              errorBuilder: (_, _, _) =>
                                                  const Icon(
                                                    Icons.add_a_photo_outlined,
                                                    color: Color(0xFF009FA4),
                                                  ),
                                            ),
                                          if (_pickingPhoto)
                                            const ColoredBox(
                                              color: Color(0x66000000),
                                              child: Center(
                                                child: SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2.5,
                                                        color: Colors.white,
                                                      ),
                                                ),
                                              ),
                                            ),
                                          const Positioned(
                                            right: 4,
                                            bottom: 4,
                                            child: CircleAvatar(
                                              radius: 16,
                                              backgroundColor: Color(
                                                0xFF009FA4,
                                              ),
                                              child: Icon(
                                                Icons.camera_alt_outlined,
                                                size: 17,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        _field(
                                          'Nombre completo',
                                          _fullName,
                                          Icons.badge_outlined,
                                        ),
                                        _dropdownField(
                                          label: 'Especialidad',
                                          value: _specialty,
                                          selectedTitle: _specialtyTitle,
                                          icon: Icons.medical_services_outlined,
                                          items: _medicalSpecialties,
                                          onChanged: (value) => setState(() {
                                            _specialty = value;
                                            _specialtyTitle = _optionTitleFor(
                                              value,
                                              _medicalSpecialties,
                                            );
                                          }),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              _field(
                                'Correo electrónico',
                                _email,
                                Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                error: _emailError,
                              ),
                              _field(
                                'Celular',
                                _cellphone,
                                Icons.phone_outlined,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                error:
                                    _submitted && _cellphone.text.trim().isEmpty
                                    ? 'Ingresa tu número de celular.'
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _ProfileCard(
                          icon: Icons.lock_outline_rounded,
                          title: 'Seguridad',
                          subtitle: 'Actualiza tu contraseña si lo deseas.',
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: TextFormField(
                                  initialValue: widget.session.username,
                                  readOnly: true,
                                  enableInteractiveSelection: true,
                                  style: const TextStyle(fontSize: 14),
                                  decoration: InputDecoration(
                                    labelText: 'Nombre de usuario',
                                    helperText:
                                        'El nombre de usuario no se puede cambiar.',
                                    helperStyle: const TextStyle(fontSize: 11),
                                    prefixIcon: const Icon(
                                      Icons.person_outline,
                                    ),
                                    suffixIcon: const Icon(
                                      Icons.lock_outline,
                                      size: 18,
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF4F7FA),
                                    border: _fieldBorder(),
                                    enabledBorder: _fieldBorder(),
                                  ),
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(13),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4FBFB),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFD8F0ED),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.lock_outline_rounded,
                                      color: Color(0xFF009FA4),
                                      size: 20,
                                    ),
                                    SizedBox(width: 9),
                                    Expanded(
                                      child: RichText(
                                        text: const TextSpan(
                                          style: TextStyle(
                                            color: Color(0xFF435678),
                                            fontSize: 13,
                                            height: 1.3,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: 'Cambiar contraseña\n',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            TextSpan(
                                              text:
                                                  'Déjalo vacío si no deseas modificarla.',
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _field(
                                'Contraseña nueva',
                                _password,
                                Icons.lock_outline,
                                obscure: true,
                                required: false,
                              ),
                              _field(
                                'Repetir contraseña nueva',
                                _repeatPassword,
                                Icons.lock_outline,
                                obscure: true,
                                required: false,
                                error:
                                    _submitted &&
                                        _password.text.isNotEmpty &&
                                        _password.text != _repeatPassword.text
                                    ? 'Las contraseñas deben coincidir.'
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _ProfileCard(
                          icon: Icons.account_balance_outlined,
                          title: 'Información de pago',
                          subtitle:
                              'Cuenta bancaria donde recibirás tus comisiones. Los campos con * son obligatorios.',
                          child: Column(
                            children: [
                              _field(
                                'Número de cuenta bancaria',
                                _bankAccountNumber,
                                Icons.account_balance_outlined,
                                error: _bankAccountNumberError(
                                  _bankAccountNumber.text,
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),
                              _dropdownField(
                                label: 'Tipo de cuenta',
                                value: _bankAccountType,
                                selectedTitle: _bankAccountType,
                                icon: Icons.account_balance_wallet_outlined,
                                items: _bankAccountTypes,
                                onChanged: (value) =>
                                    setState(() => _bankAccountType = value),
                              ),
                              _dropdownField(
                                label: 'Banco',
                                value: _bankName,
                                selectedTitle: _bankName,
                                icon: Icons.account_balance_outlined,
                                items: _banks,
                                onChanged: (value) =>
                                    setState(() => _bankName = value),
                              ),
                              _field(
                                'Nombre del dueño de la cuenta',
                                _bankAccountHolder,
                                Icons.person_outline_rounded,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 54,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_rounded, size: 22),
                            label: const Text('GUARDAR CAMBIOS'),
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Cerrar sesión'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFD63B4A),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
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
  );

  Widget _field(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool obscure = false,
    bool required = true,
    String? error,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        obscureText: obscure,
        style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 15),
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF647194)),
          prefixIcon: Icon(icon, size: 21, color: const Color(0xFF435678)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 15,
          ),
          border: _fieldBorder(),
          enabledBorder: _fieldBorder(),
          focusedBorder: _fieldBorder(
            color: const Color(0xFF009FA4),
            width: 1.5,
          ),
          errorText:
              error ?? (required ? _required(controller.text, label) : null),
        ),
      ),
    ),
  );

  Widget _dropdownField({
    required String label,
    required String? value,
    String? selectedTitle,
    required IconData icon,
    required List<ProfileOption> items,
    required ValueChanged<String?> onChanged,
    bool required = true,
  }) {
    final hasSelectedValue = items.any((item) => item.value == value);
    final displayItems = value != null && value.isNotEmpty && !hasSelectedValue
        ? [ProfileOption(value: value, title: selectedTitle ?? value), ...items]
        : items;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        initialValue: displayItems.any((item) => item.value == value)
            ? value
            : null,
        isExpanded: true,
        style: const TextStyle(
          color: Color(0xFF24364B),
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Color(0xFF435678),
          size: 22,
        ),
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF647194)),
          prefixIcon: Icon(icon, size: 21, color: const Color(0xFF435678)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 15,
          ),
          border: _fieldBorder(),
          enabledBorder: _fieldBorder(),
          focusedBorder: _fieldBorder(
            color: const Color(0xFF009FA4),
            width: 1.5,
          ),
          errorText: required ? _requiredSelection(value, label) : null,
        ),
        items: displayItems
            .map(
              (item) => DropdownMenuItem(
                value: item.value,
                child: Text(
                  item.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF24364B),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  OutlineInputBorder _fieldBorder({
    Color color = const Color(0xFFD5DEF0),
    double width = 1,
  }) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: BorderSide(color: color, width: width),
  );
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(bottom: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF10264C),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF647194),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        child,
      ],
    ),
  );
}
