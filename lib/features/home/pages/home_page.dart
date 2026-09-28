import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
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
  final _notes = TextEditingController();
  final _cellphone = TextEditingController();
  XFile? _orderPhoto;
  String? _audioPath;
  bool _isRecording = false;
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
    _restoreDraft();
  }

  @override
  void dispose() {
    _cellphone.removeListener(_saveDraft);
    _notes.removeListener(_saveDraft);
    _notes.dispose();
    _cellphone.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _restoreDraft() async {
    final draft = await HomeDraftStore.load(widget.session);
    if (!mounted || draft == null) return;
    final exams = draft['exams'];
    setState(() {
      _inputMode = draft['inputMode']?.toString() ?? 'exams';
      _cellphone.text = draft['cellphone']?.toString() ?? '';
      _notes.text = draft['notes']?.toString() ?? '';
      final photoPath = draft['orderPhotoPath']?.toString();
      _orderPhoto = photoPath == null || photoPath.isEmpty
          ? null
          : XFile(photoPath);
      final audioPath = draft['audioPath']?.toString();
      _audioPath = audioPath == null || audioPath.isEmpty ? null : audioPath;
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
    final directory = await getTemporaryDirectory();
    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.opus),
      path:
          '${directory.path}/nota-${DateTime.now().millisecondsSinceEpoch}.ogg',
    );
    if (mounted) setState(() => _isRecording = true);
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
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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
    _showMessage(result.message);
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

  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

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

  String get _welcomeText {
    final fullName = widget.session.fullName?.trim();
    if (fullName == null || fullName.isEmpty) {
      return 'Bienvenid@, ${widget.session.username}.';
    }
    return 'Bienvenid@, ${widget.session.username} ($fullName).';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF47D1B6),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 405),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
          child: Column(
            children: [
              Image.asset('assets/images/logo-prod-chequea.png', width: 360),
              const SizedBox(height: 8),
              Text(
                '${AppConfig.countries.firstWhere((item) => item.name == widget.session.country).flag}  ${widget.session.country}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _cellphone,
                style: const TextStyle(color: Color(0xFF1A1A1A)),
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: 'Celular',
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 14),
              _InputModeSelector(
                selectedMode: _inputMode,
                onSelected: (mode) {
                  setState(() => _inputMode = mode);
                  _saveDraft();
                },
              ),
              if (_orderPhoto != null || _audioPath != null || _isRecording)
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
                        color: Colors.white,
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
                  onSearchActivity: (isSearching) =>
                      setState(() => _isSearchingExams = isSearching),
                ),
                const SizedBox(height: 14),
                if (_selectedExams.isNotEmpty)
                  _SelectedExamsSummary(
                    exams: _selectedExams,
                    totalClinics: _totalClinics,
                    isLoading: _loadingClinics,
                    onRemove: _removeExam,
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
                    style: const TextStyle(color: Color(0xFF1A1A1A)),
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
                        color: Colors.white,
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
                  attachmentLabel: _isRecording
                      ? 'Grabando… toque “Detener grabación” al terminar.'
                      : _audioPath == null
                      ? null
                      : 'Nota de voz adjunta.',
                  secondaryLabel: _isRecording
                      ? 'Detener grabación'
                      : 'Grabar nota',
                  secondaryIcon: _isRecording ? Icons.stop_circle : Icons.mic,
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
                      : SvgPicture.asset(
                          'assets/svg/whatsapp.svg',
                          width: 16,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                  label: Text(_sending ? 'ENVIANDO…' : 'ENVIAR'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF24364B),
                  ),
                ),
              ),
              const SizedBox(height: 48),
              Text(
                _welcomeText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              _Action(
                label: 'MIS ENVIADOS',
                icon: Icons.send,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SentMessagesPage(session: widget.session),
                  ),
                ),
              ),
              _Action(
                label: 'MIS REFERENCIAS',
                icon: Icons.calendar_month,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        ReferredAppointmentsPage(session: widget.session),
                  ),
                ),
              ),
              _Action(
                label: 'COPIAR MI ENLACE DE INVITACIÓN',
                icon: Icons.content_copy,
                onPressed: () => _info(
                  'Enlace copiado',
                  'El enlace de invitación está listo para compartir.',
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  await HomeLocalDataStore.clearFor(widget.session);
                  await SessionStore.clear();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (_) => false,
                  );
                },
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text(
                  'Cerrar sesión',
                  style: TextStyle(
                    color: Colors.white,
                    decoration: TextDecoration.underline,
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
  }

  void _removeExam(_ExamOption exam) {
    setState(() => _selectedExams.remove(exam));
    _refreshClinicsPreview();
    _saveDraft();
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
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
    required this.onShowClinics,
  });
  final List<_ExamOption> exams;
  final int? totalClinics;
  final bool isLoading;
  final ValueChanged<_ExamOption> onRemove;
  final VoidCallback? onShowClinics;

  @override
  Widget build(BuildContext context) => Column(
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
                    color: Colors.white,
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
}

class _InputModeSelector extends StatelessWidget {
  const _InputModeSelector({
    required this.selectedMode,
    required this.onSelected,
  });
  final String selectedMode;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 46,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 1,
          child: _ModeButton(
            label: 'Lista de exámenes',
            icon: Icons.format_list_bulleted,
            selected: selectedMode == 'exams',
            onPressed: () => onSelected('exams'),
          ),
        ),
        const SizedBox(width: 4),
        _ModeLabel(
          icon: Icons.camera_alt,
          label: 'Orden médica',
          selected: selectedMode == 'photo',
          flex: 1,
          onPressed: () => onSelected('photo'),
        ),
        const SizedBox(width: 4),
        _ModeLabel(
          icon: Icons.mic,
          label: 'Grabar nota',
          selected: selectedMode == 'voice',
          flex: 1,
          onPressed: () => onSelected('voice'),
        ),
      ],
    ),
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
  });
  final String title;
  final String? attachmentLabel;
  final String? primaryLabel;
  final IconData? primaryIcon;
  final VoidCallback? onPrimary;
  final String secondaryLabel;
  final IconData secondaryIcon;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
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
        if (primaryLabel != null) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onPrimary,
              icon: Icon(primaryIcon),
              label: Text(primaryLabel!),
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
        if (attachmentLabel != null) ...[
          const SizedBox(height: 10),
          Text(
            attachmentLabel!,
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

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 14),
    label: Text(
      label.startsWith('Lista') ? 'Exámenes' : label,
      maxLines: 1,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
    ),
    style: OutlinedButton.styleFrom(
      foregroundColor: selected ? Colors.white : const Color(0xFF18304A),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
      minimumSize: Size.zero,
      visualDensity: VisualDensity.compact,
      side: BorderSide(
        color: selected ? Colors.white : Colors.transparent,
        width: selected ? 2 : 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
  );
}

class _ModeLabel extends StatelessWidget {
  const _ModeLabel({
    required this.icon,
    required this.label,
    required this.selected,
    required this.flex,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final int flex;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? Colors.white : const Color(0xFF18304A),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
        minimumSize: Size.zero,
        visualDensity: VisualDensity.compact,
        side: BorderSide(
          color: selected ? Colors.white : Colors.transparent,
          width: selected ? 2 : 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
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
            height: 44,
            child: Row(
              children: [
                const SizedBox(width: 12),
                SvgPicture.asset(
                  'assets/svg/health-checkup.svg',
                  width: 22,
                  height: 22,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF9C9C9C),
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Examen',
                    style: TextStyle(color: Color(0xFF555555)),
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
