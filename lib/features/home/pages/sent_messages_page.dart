import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/navigation/app_page_route.dart';
import '../../auth/models/user_session.dart';
import '../../auth/pages/login_page.dart';
import '../../auth/services/auth_service.dart';
import '../../auth/services/session_store.dart';
import 'referred_appointments_page.dart';
import 'home_page.dart';
import '../services/sent_messages_service.dart';
import '../widgets/app_notice_dialog.dart';
import '../widgets/commissions_coming_soon_dialog.dart';

class SentMessagesPage extends StatefulWidget {
  const SentMessagesPage({super.key, required this.session});
  final UserSession session;

  @override
  State<SentMessagesPage> createState() => _SentMessagesPageState();
}

class _SentMessagesPageState extends State<SentMessagesPage> {
  final _cellphone = TextEditingController();
  final _scrollController = ScrollController();
  final _service = const SentMessagesService();
  late UserSession _session;
  DateTime? _startDate;
  DateTime? _endDate;
  SentMessagesResult? _data;
  SentMessagesResult? _sourceData;
  String? _error;
  bool _loading = true;
  bool _filtering = false;
  bool _sessionExpired = false;
  bool _filtersOpen = false;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _restoreCacheAndRefresh();
  }

  @override
  void dispose() {
    _cellphone.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  Future<void> _load({int page = 1, bool announceFiltering = false}) async {
    final currentData = _data;
    final changesPage = currentData != null && currentData.page != page;
    if (changesPage) {
      _scrollToTop();
    }
    setState(() {
      _loading = true;
      _error = null;
      _filtering = announceFiltering;
      final sourceData = _sourceData;
      if (sourceData != null) _data = _applyLocalFilters(sourceData);
    });
    try {
      final data = await _fetch(page);
      await SentMessagesCache.save(
        session: _session,
        page: page,
        startDate: _startDate,
        endDate: _endDate,
        cellphone: _cellphone.text,
        result: data,
      );
      if (mounted) {
        setState(() {
          _sourceData = data;
          _data = _applyLocalFilters(data);
        });
        _scrollToTop();
      }
    } on SentMessagesException {
      if (mounted) {
        setState(() {
          if (_data == null) {
            _error = 'No fue posible cargar los mensajes.';
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _filtering = false;
        });
      }
    }
  }

  Future<SentMessagesResult> _fetch(int page) async {
    try {
      return await _service.fetch(
        session: _session,
        page: page,
        startDate: _startDate,
        endDate: _endDate,
        cellphone: _cellphone.text,
      );
    } on SentMessagesException {
      final refresh = await const AuthService().refreshSession(_session);
      final refreshed = refresh.session;
      if (refreshed == null) {
        if (refresh.invalid) {
          await SessionStore.clear();
          if (mounted) setState(() => _sessionExpired = true);
        }
        rethrow;
      }
      _session = refreshed;
      await SessionStore.save(refreshed);
      return _service.fetch(
        session: refreshed,
        page: page,
        startDate: _startDate,
        endDate: _endDate,
        cellphone: _cellphone.text,
      );
    }
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _restoreCacheAndRefresh() async {
    final cached = await SentMessagesCache.load(
      session: _session,
      page: 1,
      startDate: _startDate,
      endDate: _endDate,
      cellphone: _cellphone.text,
    );
    if (!mounted) return;
    if (cached != null) {
      setState(() {
        _sourceData = cached;
        _data = cached;
      });
    }
    await _load();
  }

  Future<void> _pickDate(bool start) async {
    var cleared = false;
    final selected = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) => _ClearableDatePicker(
        initialDate: start
            ? (_startDate ?? DateTime.now())
            : (_endDate ?? DateTime.now()),
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        onClear: () => cleared = true,
      ),
    );
    if (cleared && mounted) {
      setState(() {
        if (start) {
          _startDate = null;
        } else {
          _endDate = null;
        }
      });
      return;
    }
    if (selected != null) {
      setState(() {
        if (start) {
          _startDate = selected;
        } else {
          _endDate = selected;
        }
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _cellphone.clear();
    });
    _load(announceFiltering: true);
  }

  SentMessagesResult _applyLocalFilters(SentMessagesResult data) {
    final phone = _cellphone.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (_startDate == null && _endDate == null && phone.isEmpty) return data;
    final messages = data.messages.where((message) {
      final messagePhone = message.cellphone.replaceAll(RegExp(r'[^0-9]'), '');
      if (phone.isNotEmpty && messagePhone != phone) return false;
      final date = DateTime.tryParse(message.createdDate ?? '');
      final startDate = _startDate;
      if (startDate != null && (date == null || date.isBefore(startDate))) {
        return false;
      }
      final endDate = _endDate;
      if (endDate != null &&
          (date == null ||
              !date.isBefore(endDate.add(const Duration(days: 1))))) {
        return false;
      }
      return true;
    }).toList();
    return SentMessagesResult(
      total: messages.length,
      page: 1,
      perPage: data.perPage,
      messages: messages,
    );
  }

  String _date(DateTime? value) => value == null
      ? ''
      : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  void _goHome() => Navigator.of(
    context,
  ).pushReplacement(appPageRoute(HomePage(session: _session)));

  @override
  Widget build(BuildContext context) => Scaffold(
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
        onPressed: _goHome,
      ),
      centerTitle: true,
      title: const Text(
        'Enviados',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      actions: [const HeaderNoticeActions()],
    ),
    body: SafeArea(top: false, bottom: false, child: _body()),
    bottomNavigationBar: _SentMessagesBottomMenu(session: _session),
  );

  Widget _body() {
    final data = _data;
    final error = _error;
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              if (!_sessionExpired) ...[SliverToBoxAdapter(child: _filters())],
              if (_sessionExpired)
                SliverFillRemaining(child: _sessionExpiredState())
              else if (_filtering)
                SliverFillRemaining(child: _filteringState())
              else if (_loading && data == null)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF009FA4)),
                  ),
                )
              else if (error != null)
                SliverFillRemaining(
                  child: Center(
                    child: Text(
                      error,
                      style: const TextStyle(color: Color(0xFF24364B)),
                    ),
                  ),
                )
              else if (data == null || data.messages.isEmpty)
                SliverFillRemaining(child: _emptyMessagesState())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, index) => _MessageItem(
                        message: data.messages[index],
                        number: index + 1 + ((data.page - 1) * data.perPage),
                      ),
                      childCount: data.messages.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (!_sessionExpired && data != null && data.messages.isNotEmpty)
          _pagination(data),
      ],
    );
  }

  Widget _emptyMessagesState() => Center(
    child: Container(
      margin: const EdgeInsets.all(28),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFB9E9DF)),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.send_outlined, size: 38, color: Color(0xFF24364B)),
          SizedBox(height: 12),
          Text(
            'No se encontraron mensajes enviados en el historial.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF24364B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _sessionExpiredState() => Center(
    child: Container(
      margin: const EdgeInsets.all(28),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_clock_outlined, color: Color(0xFF24364B)),
          const SizedBox(height: 12),
          const Text(
            'Tu sesión expiró. Inicia sesión nuevamente para ver los mensajes.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _goToLogin,
            child: const Text('Iniciar sesión'),
          ),
        ],
      ),
    ),
  );

  Widget _filteringState() => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: Color(0xFF009FA4)),
        SizedBox(height: 14),
        Text(
          'Aplicando filtros...',
          style: TextStyle(
            color: Color(0xFF24364B),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _filters() => Container(
    margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFE),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE4EAF4)),
    ),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(6),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () => setState(() => _filtersOpen = !_filtersOpen),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 17,
                      backgroundColor: Color(0xFFD2F1FB),
                      foregroundColor: Color(0xFF24364B),
                      child: Icon(Icons.tune, size: 19),
                    ),
                    const SizedBox(width: 11),
                    const Expanded(
                      child: Text(
                        'Filtrar enviados',
                        style: TextStyle(
                          color: Color(0xFF24364B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF47D1B6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _filtersOpen
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 19,
                        color: const Color(0xFF24364B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_filtersOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        label: 'Fecha desde',
                        value: _date(_startDate),
                        onTap: () => _pickDate(true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DateField(
                        label: 'Fecha hasta',
                        value: _date(_endDate),
                        onTap: () => _pickDate(false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cellphone,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(
                          color: Color(0xFF10264C),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.phone_outlined,
                            color: Color(0xFF10264C),
                          ),
                          hintText: 'Celular',
                          hintStyle: const TextStyle(
                            color: Color(0xFF647194),
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 15,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFE4EAF4),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFE4EAF4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF009FA4),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFF009FA4),
                            disabledForegroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: _loading
                              ? null
                              : () => _load(announceFiltering: true),
                          icon: const Icon(Icons.search_rounded, size: 24),
                          label: const Text('Filtrar'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 42,
                      child: OutlinedButton.icon(
                        style: const ButtonStyle(
                          foregroundColor: WidgetStatePropertyAll(
                            Color(0xFF009FA4),
                          ),
                          side: WidgetStatePropertyAll(
                            BorderSide(color: Color(0xFF009FA4)),
                          ),
                          padding: WidgetStatePropertyAll(
                            EdgeInsets.symmetric(horizontal: 14),
                          ),
                          shape: WidgetStatePropertyAll(StadiumBorder()),
                          textStyle: WidgetStatePropertyAll(
                            TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        onPressed: _loading ? null : _clearFilters,
                        icon: const Icon(Icons.restart_alt, size: 18),
                        label: const Text('Limpiar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _pagination(SentMessagesResult data) => Container(
    color: const Color(0xFF24364B),
    child: SafeArea(
      top: false,
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _paginationLabel(
                  page: data.page,
                  perPage: data.perPage,
                  visible: data.messages.length,
                  total: data.total,
                ),
                style: const TextStyle(fontSize: 13, color: Color(0xFFF7FAFF)),
              ),
            ),
            IconButton(
              constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              onPressed: data.page > 1 && !_loading
                  ? () => _load(page: data.page - 1)
                  : null,
              icon: const Icon(Icons.chevron_left, color: Color(0xFFF7FAFF)),
            ),
            Text(
              '${data.page}',
              style: const TextStyle(color: Color(0xFFF7FAFF)),
            ),
            IconButton(
              constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              onPressed: data.hasNext && !_loading
                  ? () => _load(page: data.page + 1)
                  : null,
              icon: const Icon(Icons.chevron_right, color: Color(0xFFF7FAFF)),
            ),
          ],
        ),
      ),
    ),
  );

  String _paginationLabel({
    required int page,
    required int perPage,
    required int visible,
    required int total,
  }) {
    if (visible == 0) return 'Mostrando 0 de $total mensajes';
    final first = ((page - 1) * perPage) + 1;
    final last = first + visible - 1;
    return 'Mostrando $first–$last de $total mensajes';
  }
}

class _ClearableDatePicker extends StatefulWidget {
  const _ClearableDatePicker({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.onClear,
  });
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final VoidCallback onClear;

  @override
  State<_ClearableDatePicker> createState() => _ClearableDatePickerState();
}

class _ClearableDatePickerState extends State<_ClearableDatePicker> {
  late DateTime _selected = widget.initialDate;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Seleccionar fecha'),
    contentPadding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
    content: SizedBox(
      width: 320,
      height: 330,
      child: CalendarDatePicker(
        initialDate: _selected,
        firstDate: widget.firstDate,
        lastDate: widget.lastDate,
        onDateChanged: (value) => setState(() => _selected = value),
      ),
    ),
    actions: [
      TextButton.icon(
        onPressed: () {
          widget.onClear();
          Navigator.of(context).pop();
        },
        icon: const Icon(Icons.clear),
        label: const Text('Limpiar'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_selected),
        child: const Text('OK'),
      ),
    ],
  );
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 7),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF24364B),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 62,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 19,
                    color: Color(0xFF10264C),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      value.isEmpty ? 'Seleccionar' : value,
                      style: TextStyle(
                        color: value.isEmpty
                            ? const Color(0xFF647194)
                            : const Color(0xFF10264C),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

@pragma('vm:entry-point')
class _MessageItemOld extends StatelessWidget {
  const _MessageItemOld({required this.message, required this.number});
  final SentMessage message;
  final int number;

  String _formattedDate(String? value) {
    if (value == null || value.isEmpty) return 'Fecha no disponible';
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    const months = [
      'ene.',
      'feb.',
      'mar.',
      'abr.',
      'may.',
      'jun.',
      'jul.',
      'ago.',
      'sept.',
      'oct.',
      'nov.',
      'dic.',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final plain = message.plaintextServices?.trim() ?? '';
    final sender = message.referrerName.isEmpty
        ? message.referrerUsername
        : message.referrerName;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE4EAF4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: const Color(0xFF47D1B6),
                  foregroundColor: const Color(0xFF24364B),
                  child: Text(
                    '$number',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sender,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (message.referrerUsername.isNotEmpty)
                        Text(
                          '@${message.referrerUsername}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF24364B),
                          ),
                        ),
                    ],
                  ),
                ),
                if (message.createdDate != null)
                  _DateBadge(
                    date: _formattedDate(message.createdDate),
                    time: message.createdTime,
                  ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 11),
              child: Divider(height: 1, color: Color(0xFFB9E9DF)),
            ),
            _DetailRow(icon: Icons.phone_outlined, text: message.cellphone),
            const SizedBox(height: 8),
            const _DetailRow(
              icon: Icons.medical_information_outlined,
              text: 'Exámenes enviados',
              emphasized: true,
            ),
            const SizedBox(height: 4),
            if (plain.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(plain, style: const TextStyle(height: 1.35)),
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: message.services
                      .map(
                        (service) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            '• $service',
                            style: const TextStyle(height: 1.28),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageItem extends StatefulWidget {
  const _MessageItem({required this.message, required this.number});
  final SentMessage message;
  final int number;
  @override
  State<_MessageItem> createState() => _MessageItemState();
}

class _MessageItemState extends State<_MessageItem> {
  bool _expanded = false;

  Color _avatarBackground(int index) {
    const colors = [
      Color(0xFFE3F0FF),
      Color(0xFFF5E8FA),
      Color(0xFFE1F6EC),
      Color(0xFFFFF2D9),
    ];
    return colors[(index - 1) % colors.length];
  }

  Color _avatarColor(int index) {
    const colors = [
      Color(0xFF2C7BE5),
      Color(0xFF9943C6),
      Color(0xFF20A765),
      Color(0xFFF0AA2D),
    ];
    return colors[(index - 1) % colors.length];
  }

  String _displayName(String value) {
    if (value != value.toUpperCase()) return value;
    return value
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _formattedDate(String? value) {
    final date = value == null ? null : DateTime.tryParse(value);
    if (date == null) {
      return value?.isNotEmpty == true
          ? value ?? 'Fecha no disponible'
          : 'Fecha no disponible';
    }
    const months = [
      'ene.',
      'feb.',
      'mar.',
      'abr.',
      'may.',
      'jun.',
      'jul.',
      'ago.',
      'sept.',
      'oct.',
      'nov.',
      'dic.',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final plain = message.plaintextServices?.trim() ?? '';
    final expandable = plain.isEmpty && message.services.length > 5;
    final services = expandable && !_expanded
        ? message.services.take(5)
        : message.services;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE4EAF4)),
      ),
      child: InkWell(
        onTap: expandable ? () => setState(() => _expanded = !_expanded) : null,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 27,
                    backgroundColor: _avatarBackground(widget.number),
                    child: Padding(
                      padding: const EdgeInsets.all(13),
                      child: SvgPicture.asset(
                        'assets/svg/whatsapp.svg',
                        colorFilter: ColorFilter.mode(
                          _avatarColor(widget.number),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.cellphone.isEmpty
                              ? 'Celular no disponible'
                              : message.cellphone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF10264C),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (message.createdDate != null)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_month_outlined,
                                  size: 14,
                                  color: Color(0xFF647194),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formattedDate(message.createdDate),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF647194),
                                  ),
                                ),
                                if (message.createdTime?.isNotEmpty ==
                                    true) ...[
                                  const SizedBox(width: 10),
                                  const Icon(
                                    Icons.access_time_rounded,
                                    size: 14,
                                    color: Color(0xFF647194),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    message.createdTime!,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF647194),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const _DateBadge(),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 11),
                child: Divider(height: 1, color: Color(0xFFB9E9DF)),
              ),
              if (plain.isNotEmpty)
                Text(plain, style: const TextStyle(height: 1.35))
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: services
                      .map(
                        (service) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            '• $service',
                            style: const TextStyle(height: 1.28),
                          ),
                        ),
                      )
                      .toList(),
                ),
              if (expandable)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: const Color(0xFF24364B),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _expanded
                            ? 'Ocultar exámenes'
                            : 'Ver ${message.services.length - 5} exámenes más',
                        style: const TextStyle(
                          color: Color(0xFF24364B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.text,
    this.emphasized = false,
  });
  final IconData icon;
  final String text;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: const Color(0xFF24364B)),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({this.date, this.time});
  final String? date;
  final String? time;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F6E8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Enviado',
        style: TextStyle(
          color: Color(0xFF07843F),
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SentMessagesBottomMenu extends StatelessWidget {
  const _SentMessagesBottomMenu({required this.session});

  final UserSession session;

  Future<void> _copyInviteLink(BuildContext context) async {
    final link = session.inviteLink?.trim() ?? '';
    if (link.isEmpty) {
      _showInviteDialog(
        context,
        title: 'Invitación no disponible',
        message: 'No hay un enlace de invitación disponible.',
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: link));
    if (context.mounted) {
      _showInviteDialog(
        context,
        title: 'Enlace copiado',
        message: 'El enlace de invitación está listo para compartir.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFD5DEF0))),
      ),
      padding: const EdgeInsets.fromLTRB(4, 9, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: _BottomMenuItem(
              label: 'Inicio',
              asset: 'assets/svg/Icono-Inactivo-Inicio-Botonera.svg',
              onPressed: () => Navigator.of(
                context,
              ).pushReplacement(appPageRoute(HomePage(session: session))),
            ),
          ),
          const _MenuDivider(),
          Expanded(
            child: _BottomMenuItem(
              label: 'Enviados',
              asset: 'assets/svg/Icono de enviados - líneas celeste.svg',
              selected: true,
              onPressed: () {},
            ),
          ),
          const _MenuDivider(),
          Expanded(
            child: _BottomMenuItem(
              label: 'Referencias',
              asset: 'assets/svg/Icono de referencias - líneas celestes.svg',
              onPressed: () => Navigator.of(context).pushReplacement(
                appPageRoute(ReferredAppointmentsPage(session: session)),
              ),
            ),
          ),
          const _MenuDivider(),
          Expanded(
            child: _BottomMenuItem(
              label: 'Comisiones',
              asset: 'assets/svg/Icono de comisiones - líneas gris.svg',
              onPressed: () => showCommissionsComingSoonDialog(context),
            ),
          ),
        ],
      ),
    ),
  );
}

void _showInviteDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
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
          onPressed: () => Navigator.pop(dialogContext),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF009FA4)),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 42,
    child: VerticalDivider(color: Color(0xFFD5DEF0)),
  );
}

class _BottomMenuItem extends StatelessWidget {
  const _BottomMenuItem({
    required this.label,
    required this.asset,
    this.selected = false,
    this.onPressed,
  });

  final String label;
  final String asset;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF009FA4) : const Color(0xFF10264C);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            asset,
            width: 29,
            height: 29,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
