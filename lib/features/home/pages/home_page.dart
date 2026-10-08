import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/navigation/app_page_route.dart';
import '../../auth/models/user_session.dart';
import '../../auth/pages/login_page.dart';
import '../../auth/services/session_store.dart';
import 'referred_appointments_page.dart';
import 'sent_messages_page.dart';
import '../services/message_service.dart';
import '../services/clinics_preview_service.dart';
import '../services/home_draft_store.dart';
import '../services/home_local_data_store.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.session});
  final UserSession session;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _inputMode = 'exams';
  final List<_ExamOption> _selectedExams = [];
  final _imagePicker = ImagePicker();
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  final _notes = TextEditingController();
  final _cellphone = TextEditingController();
  final _homeScrollController = ScrollController();
  XFile? _orderPhoto;
  String? _audioPath;
  bool _isRecording = false;
  bool _isPlayingAudio = false;
  bool _sending = false;
  bool _isSearchingExams = false;
  final _messageService = const MessageService();
  final _clinicsPreviewService = const ClinicsPreviewService();
  int? _totalClinics;
  String? _clinicsListUrl;
  bool _loadingClinics = false;
  int _clinicsRequestId = 0;

  @override
  void initState() {
    super.initState();
    _cellphone.addListener(_saveDraft);
    _notes.addListener(_saveDraft);
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlayingAudio = false);
    });
    _restoreDraft();
  }

  @override
  void dispose() {
    _cellphone.removeListener(_saveDraft);
    _notes.removeListener(_saveDraft);
    _notes.dispose();
    _cellphone.dispose();
    _homeScrollController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _restoreDraft() async {
    final draft = await HomeDraftStore.load(widget.session);
    if (!mounted || draft == null) return;
    final exams = draft['exams'];
    final savedAudioPath = draft['audioPath']?.toString();
    final audioPath =
        savedAudioPath == null ||
            savedAudioPath.isEmpty ||
            !savedAudioPath.toLowerCase().endsWith('.m4a')
        ? null
        : await File(savedAudioPath).exists()
        ? savedAudioPath
        : null;
    if (!mounted) return;
    setState(() {
      final savedMode = draft['inputMode']?.toString();
      _inputMode = switch (savedMode) {
        'photo' => 'photo',
        'voice' => 'voice',
        _ => 'exams',
      };
      _cellphone.text = draft['cellphone']?.toString() ?? '';
      _notes.text = draft['notes']?.toString() ?? '';
      final photoPath = draft['orderPhotoPath']?.toString();
      _orderPhoto = photoPath == null || photoPath.isEmpty
          ? null
          : XFile(photoPath);
      _audioPath = audioPath;
      if (exams is List) {
        _selectedExams
          ..clear()
          ..addAll(
            exams
                .whereType<Map>()
                .map(
                  (item) => _ExamOption(
                    (item['id'] as num?)?.toInt() ?? 0,
                    item['title']?.toString() ?? '',
                    (item['totalClinics'] as num?)?.toInt() ?? 0,
                  ),
                )
                .where((exam) => exam.id > 0 && exam.title.isNotEmpty),
          );
      }
    });
    _refreshClinicsPreview();
    _saveDraft();
  }

  Future<void> _saveDraft() => HomeDraftStore.save(widget.session, {
    'inputMode': _inputMode,
    'cellphone': _cellphone.text,
    'notes': _notes.text,
    'orderPhotoPath': _orderPhoto?.path,
    'audioPath': _audioPath,
    'exams': _selectedExams
        .map(
          (exam) => {
            'id': exam.id,
            'title': exam.title,
            'totalClinics': exam.totalClinics,
          },
        )
        .toList(),
  });

  Future<void> _pickOrderPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Elegir de galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final photo = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (photo != null && mounted) {
      setState(() => _orderPhoto = photo);
      _saveDraft();
    }
  }

  Future<void> _toggleVoiceNote() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      if (mounted) {
        setState(() {
          _isRecording = false;
          _audioPath = path;
        });
        _saveDraft();
      }
      return;
    }
    if (!await _audioRecorder.hasPermission()) {
      if (mounted) {
        _info(
          'Micrófono',
          'Debes permitir el acceso al micrófono para grabar una nota de voz.',
        );
      }
      return;
    }
    final directory = await getApplicationDocumentsDirectory();
    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path:
          '${directory.path}/nota-${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    if (mounted) setState(() => _isRecording = true);
  }

  Future<void> _toggleAudioPreview() async {
    final audioPath = _audioPath;
    if (audioPath == null || _isRecording) return;
    if (!audioPath.toLowerCase().endsWith('.m4a') ||
        !await File(audioPath).exists()) {
      if (mounted) {
        setState(() => _audioPath = null);
        _saveDraft();
        _info(
          'Nota de voz',
          'La grabación ya no está disponible. Grabe una nueva nota de voz.',
        );
      }
      return;
    }
    try {
      if (_isPlayingAudio) {
        await _audioPlayer.pause();
        if (mounted) setState(() => _isPlayingAudio = false);
        return;
      }
      await _audioPlayer.play(DeviceFileSource(audioPath));
      if (mounted) setState(() => _isPlayingAudio = true);
    } on Exception {
      if (mounted) {
        _info('Nota de voz', 'No fue posible reproducir la nota de voz.');
      }
    }
  }

  Future<void> _pickImageFile() async {
    final selection = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png'],
    );
    final path = selection?.path;
    if (path != null && mounted) {
      setState(() => _orderPhoto = XFile(path));
      _saveDraft();
    }
  }

  void _info(String title, String message) {
    if (title.startsWith('Enlace')) {
      final link = widget.session.inviteLink?.trim() ?? '';
      if (link.isEmpty) {
        _showMessage('No hay un enlace de invitación disponible.');
        return;
      }
      Clipboard.setData(ClipboardData(text: link));
    }
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF009FA4)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF10264C),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Color(0xFF435678), height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF009FA4),
            ),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_sending) return;
    final cellphone = _cellphone.text.trim();
    if (cellphone.isEmpty) {
      _showMessage('Ingrese el número celular del paciente.');
      return;
    }

    final mode = _inputMode == 'photo'
        ? 'image'
        : _inputMode == 'voice'
        ? 'audio'
        : 'list';
    final hasServices = _selectedExams.isNotEmpty;
    final plaintext = _notes.text.trim();
    if (mode == 'list' && !hasServices && plaintext.isEmpty) {
      _showMessage('Seleccione al menos un examen o escriba los exámenes.');
      return;
    }
    if (mode == 'list' &&
        plaintext.isNotEmpty &&
        !widget.session.isChequeandomeAgent) {
      _showMessage('Solo un agente de Chequeándome puede enviar texto libre.');
      return;
    }
    final filePath = mode == 'image' ? _orderPhoto?.path : _audioPath;
    if ((mode == 'image' || mode == 'audio') && filePath == null) {
      _showMessage(
        mode == 'image'
            ? 'Adjunte una orden médica.'
            : 'Adjunte o grabe una nota de voz.',
      );
      return;
    }
    if (mode == 'audio' && !await File(filePath!).exists()) {
      if (mounted) setState(() => _audioPath = null);
      _saveDraft();
      _showMessage(
        'La grabación ya no está disponible. Grabe una nueva nota de voz.',
      );
      return;
    }
    if (_isRecording) {
      _showMessage('Detenga la grabación antes de enviar.');
      return;
    }

    setState(() => _sending = true);
    final result = await _messageService.send(
      session: widget.session,
      mode: mode,
      patientCellphoneNumber: cellphone,
      serviceIds: hasServices
          ? _selectedExams.map((exam) => exam.id).toList()
          : const [],
      plaintextServices: hasServices ? null : plaintext,
      filePath: filePath,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    _showMessage(result.message, success: result.success);
    if (!result.success) return;
    setState(() {
      _cellphone.clear();
      _selectedExams.clear();
      _notes.clear();
      _orderPhoto = null;
      _audioPath = null;
    });
    _refreshClinicsPreview();
    HomeDraftStore.clear(widget.session);
  }

  void _showMessage(String message, {bool success = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: Duration(seconds: success ? 6 : 4),
        backgroundColor: success
            ? const Color(0xFF087E7A)
            : const Color(0xFF10264C),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: Colors.white,
              size: 21,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshClinicsPreview() async {
    final requestId = ++_clinicsRequestId;
    if (_selectedExams.isEmpty) {
      setState(() {
        _totalClinics = null;
        _clinicsListUrl = null;
        _loadingClinics = false;
      });
      return;
    }
    setState(() => _loadingClinics = true);
    final preview = await _clinicsPreviewService.fetch(
      session: widget.session,
      serviceIds: _selectedExams.map((exam) => exam.id).toList(),
    );
    if (!mounted || requestId != _clinicsRequestId) return;
    setState(() {
      _totalClinics = preview.totalClinics;
      _clinicsListUrl = preview.clinicsListUrl;
      _loadingClinics = false;
    });
  }

  Future<void> _openClinicsPreview() async {
    final uri = Uri.tryParse(_clinicsListUrl ?? '');
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) _showMessage('No fue posible abrir la vista previa.');
    }
  }

  String get _displayName {
    final fullName = widget.session.fullName?.trim();
    if (fullName == null || fullName.isEmpty) {
      return widget.session.username;
    }
    return fullName;
  }

  Future<void> _logout() async {
    await HomeLocalDataStore.clearFor(widget.session);
    await SessionStore.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  void _selectInputMode(String mode) {
    final nextMode = _inputMode == mode ? 'exams' : mode;
    if (_isRecording && nextMode != 'voice') {
      _audioRecorder.stop();
    }
    setState(() {
      _inputMode = nextMode;
      if (nextMode != 'voice') _isRecording = false;
    });
    _saveDraft();
    _scrollHomeToTop();
  }

  void _scrollHomeToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_homeScrollController.hasClients) {
        _homeScrollController.jumpTo(0);
      }
    });
  }

  Widget _fixedHeader() => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE5F8F7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.monitor_heart_rounded,
                      color: Color(0xFF009FA4),
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 9),
                  const Text(
                    'Chequea',
                    style: TextStyle(
                      color: Color(0xFF10264C),
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.8,
                    ),
                  ),
                ],
              ),
            ),
            _countrySelector(),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FAFF),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/images/Perfil doctores.png',
                  width: 68,
                  height: 68,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _displayName,
                  maxLines: 2,
                  softWrap: true,
                  style: const TextStyle(
                    color: Color(0xFF10264C),
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar sesión',
                onPressed: _logout,
                icon: const Icon(Icons.logout_outlined, size: 29),
                color: const Color(0xFF24364B),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _countrySelector() => Container(
    padding: const EdgeInsets.fromLTRB(11, 8, 8, 8),
    decoration: BoxDecoration(
      color: const Color(0xFFE8F8F6),
      border: Border.all(color: const Color(0xFFCBECE8)),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppConfig.countries
              .firstWhere((item) => item.name == widget.session.country)
              .flag,
          style: const TextStyle(fontSize: 15),
        ),
        const SizedBox(width: 5),
        Text(
          widget.session.country,
          style: const TextStyle(
            color: Color(0xFF24364B),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Stack(
        children: [
          Positioned.fill(
            top: 166,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 405),
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    controller: _homeScrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Transform.translate(
                          offset: Offset.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Offstage(
                                offstage: true,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 42,
                                            height: 42,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFE5F8F7),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.monitor_heart_rounded,
                                              color: Color(0xFF009FA4),
                                              size: 27,
                                            ),
                                          ),
                                          const SizedBox(width: 9),
                                          const Text(
                                            'Chequea',
                                            style: TextStyle(
                                              color: Color(0xFF10264C),
                                              fontSize: 27,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -.8,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.fromLTRB(
                                        11,
                                        8,
                                        8,
                                        8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F8F6),
                                        border: Border.all(
                                          color: const Color(0xFFCBECE8),
                                        ),
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            AppConfig.countries
                                                .firstWhere(
                                                  (item) =>
                                                      item.name ==
                                                      widget.session.country,
                                                )
                                                .flag,
                                            style: const TextStyle(
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            widget.session.country,
                                            style: const TextStyle(
                                              color: Color(0xFF24364B),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          const Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            color: Color(0xFF009FA4),
                                            size: 18,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              Offstage(
                                offstage: true,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    12,
                                    16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FAFF),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Row(
                                    children: [
                                      ClipOval(
                                        child: Image.asset(
                                          'assets/images/Perfil doctores.png',
                                          width: 68,
                                          height: 68,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          _displayName,
                                          maxLines: 2,
                                          softWrap: true,
                                          style: const TextStyle(
                                            color: Color(0xFF10264C),
                                            fontSize: 19,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Cerrar sesión',
                                        onPressed: _logout,
                                        icon: const Icon(
                                          Icons.logout_outlined,
                                          size: 19,
                                        ),
                                        color: const Color(0xFF24364B),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _cellphone,
                                style: const TextStyle(
                                  color: Color(0xFF1A1A1A),
                                  fontSize: 14,
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  hintText: 'Número de WhatsApp del paciente',
                                  hintStyle: const TextStyle(fontSize: 14),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.all(11),
                                    child: SvgPicture.asset(
                                      'assets/svg/whatsapp.svg',
                                      colorFilter: const ColorFilter.mode(
                                        Color(0xFF25D366),
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              if (_orderPhoto != null ||
                                  _audioPath != null ||
                                  _isRecording)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      _isRecording
                                          ? 'Grabando nota de voz… toque “Grabar nota” para detener.'
                                          : _orderPhoto != null
                                          ? 'Orden médica adjunta.'
                                          : 'Nota de voz adjunta.',
                                      style: const TextStyle(
                                        color: Color(0xFF24364B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 6),
                              if (_inputMode == 'exams') ...[
                                _ExamSelector(
                                  session: widget.session,
                                  onSelected: _addExam,
                                  onSearchActivity: (isSearching) => setState(
                                    () => _isSearchingExams = isSearching,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                if (_selectedExams.isNotEmpty)
                                  _SelectedExamsSummary(
                                    exams: _selectedExams,
                                    totalClinics: _totalClinics,
                                    isLoading: _loadingClinics,
                                    onRemove: _removeExam,
                                    onClear: _clearExams,
                                    onShowClinics:
                                        widget.session.isChequeandomeAgent &&
                                            _clinicsListUrl != null &&
                                            (_totalClinics ?? 0) > 0
                                        ? _openClinicsPreview
                                        : null,
                                  )
                                else if (widget.session.isChequeandomeAgent &&
                                    !_isSearchingExams) ...[
                                  TextField(
                                    controller: _notes,
                                    maxLines: 4,
                                    maxLength: 1000,
                                    style: const TextStyle(
                                      color: Color(0xFF1A1A1A),
                                    ),
                                    decoration: const InputDecoration(
                                      fillColor: Colors.white,
                                      hintText:
                                          'En esta caja de texto puede escribir exámenes que no tenga Chequeándome. Máximo 1000 caracteres.',
                                    ),
                                  ),
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Si elije uno o más exámenes no podrá utilizar esta caja de texto.',
                                      style: TextStyle(
                                        color: Color(0xFF24364B),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                              if (_inputMode == 'photo')
                                _AttachmentPane(
                                  title: 'Adjunte imagen:',
                                  attachmentLabel: _orderPhoto == null
                                      ? null
                                      : 'Imagen adjunta.',
                                  primaryLabel: 'Desde archivos',
                                  primaryIcon: Icons.attach_file,
                                  onPrimary: _pickImageFile,
                                  secondaryLabel: 'Tomar foto',
                                  secondaryIcon: Icons.camera_alt,
                                  onSecondary: _pickOrderPhoto,
                                ),
                              if (_inputMode == 'voice')
                                _AttachmentPane(
                                  title: 'Adjunte nota de voz:',
                                  previewLabel:
                                      _audioPath == null || _isRecording
                                      ? null
                                      : _isPlayingAudio
                                      ? 'Pausar nota de voz'
                                      : 'Escuchar nota de voz',
                                  previewIcon: _isPlayingAudio
                                      ? Icons.pause_circle_outline
                                      : Icons.play_circle_outline,
                                  onPreview: _audioPath == null || _isRecording
                                      ? null
                                      : _toggleAudioPreview,
                                  attachmentLabel: _isRecording
                                      ? 'Grabando… toque “Detener grabación” al terminar.'
                                      : _audioPath == null
                                      ? null
                                      : 'Nota de voz adjunta.',
                                  secondaryLabel: _isRecording
                                      ? 'Detener grabación'
                                      : 'Grabar nota',
                                  secondaryIcon: _isRecording
                                      ? Icons.stop_circle
                                      : Icons.mic,
                                  onSecondary: _toggleVoiceNote,
                                ),
                              const SizedBox(height: 28),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _sending ? null : _sendMessage,
                                  icon: _sending
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.send_rounded,
                                          size: 22,
                                        ),
                                  label: Text(
                                    _sending ? 'ENVIANDO…' : 'ENVIAR',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: .3,
                                    ),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF009FA4),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 50),
                              _InputModeSelector(
                                selectedMode: _inputMode,
                                onSelected: _selectInputMode,
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      'assets/images/Tres estrellas.png',
                                      width: 26,
                                      height: 26,
                                    ),
                                    const SizedBox(width: 7),
                                    const Text(
                                      'Impulsado por Inteligencia Artificial',
                                      style: TextStyle(
                                        color: Color(0xFF647194),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 46),
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
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 405),
              child: _fixedHeader(),
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: Container(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFD5DEF0))),
          ),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 14),
          child: Row(
            children: [
              Expanded(
                child: _Action(
                  label: 'Enviar\nmensaje',
                  selected: true,
                  icon: SvgPicture.asset(
                    'assets/svg/health-checkup.svg',
                    width: 25,
                    height: 25,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFF009FA4),
                      BlendMode.srcIn,
                    ),
                  ),
                  onPressed: () => _homeScrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                  ),
                ),
              ),
              const SizedBox(
                height: 42,
                child: VerticalDivider(color: Color(0xFFD5DEF0)),
              ),
              Expanded(
                child: _Action(
                  label: 'Mis enviados',
                  icon: SvgPicture.asset(
                    'assets/svg/Icono de enviados - líneas celeste.svg',
                    width: 29,
                    height: 29,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFF10264C),
                      BlendMode.srcIn,
                    ),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    appPageRoute(SentMessagesPage(session: widget.session)),
                  ),
                ),
              ),
              const SizedBox(
                height: 42,
                child: VerticalDivider(color: Color(0xFFD5DEF0)),
              ),
              Expanded(
                child: _Action(
                  label: 'Mis referencias',
                  icon: SvgPicture.asset(
                    'assets/svg/Icono de referencias - líneas celestes.svg',
                    width: 29,
                    height: 29,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFF10264C),
                      BlendMode.srcIn,
                    ),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    appPageRoute(
                      ReferredAppointmentsPage(session: widget.session),
                    ),
                  ),
                ),
              ),
              const SizedBox(
                height: 42,
                child: VerticalDivider(color: Color(0xFFD5DEF0)),
              ),
              Expanded(
                child: _Action(
                  label: 'Invitar a un amigo',
                  icon: SvgPicture.asset(
                    'assets/svg/Icono de invitar amigo - celeste.svg',
                    width: 29,
                    height: 29,
                  ),
                  onPressed: () => _info(
                    'Enlace copiado',
                    'El enlace de invitación está listo para compartir.',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  void _addExam(_ExamOption exam) {
    final exists = _selectedExams.any(
      (selected) => selected.title.toLowerCase() == exam.title.toLowerCase(),
    );
    if (exists) return;
    setState(() {
      _selectedExams.add(exam);
      _notes.clear();
      _isSearchingExams = false;
    });
    _refreshClinicsPreview();
    _saveDraft();
    _scrollHomeToTop();
  }

  void _removeExam(_ExamOption exam) {
    setState(() => _selectedExams.remove(exam));
    _refreshClinicsPreview();
    _saveDraft();
    _scrollHomeToTop();
  }

  void _clearExams() {
    setState(_selectedExams.clear);
    _refreshClinicsPreview();
    _saveDraft();
    _scrollHomeToTop();
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.selected = false,
  });
  final String label;
  final Widget icon;
  final VoidCallback onPressed;
  final bool selected;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: selected
          ? const Color(0xFF009FA4)
          : const Color(0xFF10264C),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 29, height: 29, child: Center(child: icon)),
        const SizedBox(height: 5),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _ExamSelector extends StatefulWidget {
  const _ExamSelector({
    required this.session,
    required this.onSelected,
    required this.onSearchActivity,
  });
  final UserSession session;
  final ValueChanged<_ExamOption> onSelected;
  final ValueChanged<bool> onSearchActivity;

  @override
  State<_ExamSelector> createState() => _ExamSelectorState();
}

class _ExamOption {
  const _ExamOption(this.id, this.title, this.totalClinics);
  final int id;
  final String title;
  final int totalClinics;
}

class _SelectedExamsSummary extends StatelessWidget {
  const _SelectedExamsSummary({
    required this.exams,
    required this.totalClinics,
    required this.isLoading,
    required this.onRemove,
    required this.onClear,
    required this.onShowClinics,
  });
  final List<_ExamOption> exams;
  final int? totalClinics;
  final bool isLoading;
  final ValueChanged<_ExamOption> onRemove;
  final VoidCallback onClear;
  final VoidCallback? onShowClinics;

  @pragma('vm:entry-point')
  Widget _legacyBuild(BuildContext context) => Column(
    children: [
      ...exams.map(
        (exam) => Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: FilledButton(
                  onPressed: () => onRemove(exam),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE83D5A),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Icon(Icons.close),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  exam.title,
                  style: const TextStyle(
                    color: Color(0xFF24364B),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 5),
      if (isLoading)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFD2F1FB),
            border: Border.all(color: const Color(0xFF24364B)),
            borderRadius: BorderRadius.circular(5),
          ),
          child: const Text(
            'Buscando lugares de atención médica…',
            style: TextStyle(color: Color(0xFF24364B)),
          ),
        )
      else
        InkWell(
          onTap: onShowClinics,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFD2F1FB),
              border: Border.all(color: const Color(0xFF24364B)),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    totalClinics == 0
                        ? 'No se encontraron lugares de atención médica para esta combinación de exámenes.'
                        : 'Se encontraron ${totalClinics ?? 0} lugares de atención médica para esta combinación de exámenes.',
                    style: const TextStyle(color: Color(0xFF24364B)),
                  ),
                ),
                if (onShowClinics != null)
                  const Icon(Icons.open_in_new, color: Color(0xFF24364B)),
              ],
            ),
          ),
        ),
    ],
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Exámenes seleccionados (${exams.length})',
              style: const TextStyle(
                color: Color(0xFF10264C),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            label: const Text('Limpiar todos', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF009FA4),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          ),
        ],
      ),
      const SizedBox(height: 7),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: exams
            .map(
              (exam) =>
                  _SelectedExamChip(exam: exam, onRemove: () => onRemove(exam)),
            )
            .toList(),
      ),
      const SizedBox(height: 14),
      if (isLoading)
        const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Buscando clínicas disponibles…'),
          ],
        )
      else
        InkWell(
          onTap: onShowClinics,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const FaIcon(
                  FontAwesomeIcons.hospital,
                  color: Color(0xFF009FA4),
                  size: 27,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    totalClinics == 0
                        ? 'No hay clínicas disponibles para esta combinación.'
                        : '${totalClinics ?? 0} ${(totalClinics ?? 0) == 1 ? 'clínica disponible' : 'clínicas disponibles'} para esta combinación.',
                    style: const TextStyle(
                      color: Color(0xFF647194),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (onShowClinics != null)
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 15,
                    color: Color(0xFF009FA4),
                  ),
              ],
            ),
          ),
        ),
    ],
  );
}

class _SelectedExamChip extends StatelessWidget {
  const _SelectedExamChip({required this.exam, required this.onRemove});
  final _ExamOption exam;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(
      maxWidth: MediaQuery.sizeOf(context).width - 70,
    ),
    padding: const EdgeInsets.fromLTRB(7, 6, 10, 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF0FAFF),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onRemove,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 27,
            height: 27,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF00AFA7)),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.close_rounded,
              size: 18,
              color: Color(0xFF00AFA7),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            exam.title,
            softWrap: true,
            style: const TextStyle(
              color: Color(0xFF10264C),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _InputModeSelector extends StatelessWidget {
  const _InputModeSelector({
    required this.selectedMode,
    required this.onSelected,
  });
  final String selectedMode;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (selectedMode == 'photo' || selectedMode == 'voice') ...[
        SizedBox(
          width: double.infinity,
          height: 41,
          child: OutlinedButton.icon(
            onPressed: () => onSelected('exams'),
            icon: const Icon(Icons.format_list_bulleted_rounded, size: 16),
            label: const Text('Lista de exámenes'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF10264C),
              side: const BorderSide(color: Color(0xFF009FA4)),
              padding: EdgeInsets.zero,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],
      SizedBox(
        height: 86,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _SecondaryModeAction(
                icon: Icons.camera_alt_outlined,
                label: 'Orden médica',
                selected: selectedMode == 'photo',
                enabled: true,
                onPressed: () => onSelected('photo'),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: VerticalDivider(color: Color(0xFFD5DEF0)),
            ),
            Expanded(
              child: _SecondaryModeAction(
                icon: Icons.keyboard_voice_rounded,
                label: 'Nota de voz',
                selected: selectedMode == 'voice',
                enabled: true,
                onPressed: () => onSelected('voice'),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _AttachmentPane extends StatelessWidget {
  const _AttachmentPane({
    required this.title,
    required this.secondaryLabel,
    required this.secondaryIcon,
    required this.onSecondary,
    this.attachmentLabel,
    this.primaryLabel,
    this.primaryIcon,
    this.onPrimary,
    this.previewLabel,
    this.previewIcon,
    this.onPreview,
  });
  final String title;
  final String? attachmentLabel;
  final String? primaryLabel;
  final IconData? primaryIcon;
  final VoidCallback? onPrimary;
  final String? previewLabel;
  final IconData? previewIcon;
  final VoidCallback? onPreview;
  final String secondaryLabel;
  final IconData secondaryIcon;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFD5DEF0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF24364B),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        if (primaryLabel case final label?) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onPrimary,
              icon: Icon(primaryIcon),
              label: Text(label),
            ),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onSecondary,
            icon: Icon(secondaryIcon),
            label: Text(secondaryLabel),
          ),
        ),
        if (previewLabel case final label?) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onPreview,
              icon: Icon(previewIcon),
              label: Text(label),
            ),
          ),
        ],
        if (attachmentLabel case final label?) ...[
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF24364B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    ),
  );
}

class _SecondaryModeAction extends StatelessWidget {
  const _SecondaryModeAction({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: enabled ? onPressed : null,
    style: TextButton.styleFrom(
      foregroundColor: enabled
          ? selected
                ? const Color(0xFF009FA4)
                : const Color(0xFF10264C)
          : const Color(0xFF9AA8B8),
      backgroundColor: enabled && selected
          ? const Color(0xFFE5F8F7)
          : Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 32),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _ExamSelectorState extends State<_ExamSelector> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  bool _expanded = false;
  bool _loading = false;
  int _searchRequestId = 0;
  List<_ExamOption> _results = const [];

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _searchServices(String value) async {
    final query = value.trim();
    final requestId = ++_searchRequestId;
    if (query.length < 2) {
      setState(() {
        _results = const [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    final country = AppConfig.forCountry(widget.session.country);
    final apiKey = country.apiKeyFor(widget.session.country);
    try {
      final response = await http.get(
        Uri.parse(
          '${Uri.parse(country.loginUrl).origin}/api/chequea-api/v1/services/search',
        ).replace(queryParameters: {'q': query}),
        headers: {
          'x-api-key': apiKey,
          'Authorization': 'Bearer ${widget.session.accessToken}',
        },
      );
      final data = jsonDecode(response.body);
      final items = data is Map<String, dynamic> && data['results'] is List
          ? (data['results'] as List)
                .whereType<Map>()
                .map(
                  (item) => _ExamOption(
                    (item['id'] as num?)?.toInt() ?? 0,
                    item['title']?.toString() ?? '',
                    (item['total_clinics'] as num?)?.toInt() ?? 0,
                  ),
                )
                .where((item) => item.id > 0 && item.title.isNotEmpty)
                .toList()
          : <_ExamOption>[];
      if (mounted && requestId == _searchRequestId) {
        setState(() => _results = items);
      }
    } on Exception {
      if (mounted && requestId == _searchRequestId) {
        setState(() => _results = const []);
      }
    } finally {
      if (mounted && requestId == _searchRequestId) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            setState(() => _expanded = !_expanded);
            if (_expanded) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _searchFocus.requestFocus(),
              );
            }
          },
          child: SizedBox(
            height: 58,
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(
                  Icons.assignment_outlined,
                  size: 27,
                  color: Color(0xFF10264C),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Selecciona un examen',
                    style: TextStyle(color: Color(0xFF647194), fontSize: 15),
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: const Color(0xFF777777),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(5),
            child: TextField(
              controller: _search,
              focusNode: _searchFocus,
              autofocus: true,
              onChanged: (value) {
                widget.onSearchActivity(value.trim().isNotEmpty);
                _searchServices(value);
              },
              style: const TextStyle(color: Color(0xFF1A1A1A)),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
              ),
            ),
          ),
          if (_search.text.trim().length < 2)
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 4, 8, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Por favor, introduzca al menos 2 caracteres más',
                  style: TextStyle(color: Color(0xFF222222)),
                ),
              ),
            )
          else if (_loading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            )
          else if (_results.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No se encontraron exámenes.',
                  style: TextStyle(color: Color(0xFF333333)),
                ),
              ),
            )
          else
            ..._results.map(
              (exam) => ListTile(
                dense: true,
                title: Text(
                  exam.title,
                  style: const TextStyle(color: Color(0xFF333333)),
                ),
                onTap: () {
                  widget.onSelected(exam);
                  widget.onSearchActivity(false);
                  setState(() => _expanded = false);
                },
              ),
            ),
        ],
      ],
    ),
  );
}
