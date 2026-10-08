import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/navigation/app_page_route.dart';
import '../../auth/models/user_session.dart';
import '../../auth/pages/login_page.dart';
import '../../auth/services/auth_service.dart';
import '../../auth/services/session_store.dart';
import 'sent_messages_page.dart';
import '../services/referred_appointments_service.dart';

class ReferredAppointmentsPage extends StatefulWidget {
  const ReferredAppointmentsPage({super.key, required this.session});
  final UserSession session;

  @override
  State<ReferredAppointmentsPage> createState() =>
      _ReferredAppointmentsPageState();
}

class _ReferredAppointmentsPageState extends State<ReferredAppointmentsPage> {
  final _service = const ReferredAppointmentsService();
  final _scrollController = ScrollController();
  late UserSession _session;
  String? _status;
  String? _attendance;
  DateTime? _creationDateStart;
  DateTime? _creationDateEnd;
  DateTime? _appointmentDateStart;
  DateTime? _appointmentDateEnd;
  ReferredAppointmentsResult? _data;
  ReferredAppointmentsResult? _sourceData;
  bool _loading = true;
  String? _error;
  bool _filtersOpen = false;
  bool _filtering = false;
  bool _sessionExpired = false;
  int _loadRequestId = 0;

  bool get _hasActiveFilters =>
      _status != null ||
      _attendance != null ||
      _creationDateStart != null ||
      _creationDateEnd != null ||
      _appointmentDateStart != null ||
      _appointmentDateEnd != null;
  bool get _attendanceIsRestricted =>
      _status == 'cancel' || _status == 'pending' || _status == 'rescheduling';

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _restoreCacheAndRefresh();
  }

  @override
  void dispose() {
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
    final requestId = ++_loadRequestId;
    setState(() {
      _loading = true;
      _error = null;
      _filtering = announceFiltering;
      final sourceData = _sourceData;
      if (sourceData != null) _data = _applyLocalFilters(sourceData);
    });
    try {
      final cached = await ReferredAppointmentsCache.load(
        session: _session,
        page: page,
        status: _status,
        attendance: _attendance,
        creationDateStart: _creationDateStart,
        creationDateEnd: _creationDateEnd,
        appointmentDateStart: _appointmentDateStart,
        appointmentDateEnd: _appointmentDateEnd,
      );
      if (mounted && cached != null && requestId == _loadRequestId) {
        setState(() {
          _sourceData = cached;
          _data = _applyLocalFilters(cached);
          _loading = false;
        });
        _scrollToTop();
      }
      final data = await _fetch(page);
      await ReferredAppointmentsCache.save(
        session: _session,
        page: page,
        status: _status,
        attendance: _attendance,
        creationDateStart: _creationDateStart,
        creationDateEnd: _creationDateEnd,
        appointmentDateStart: _appointmentDateStart,
        appointmentDateEnd: _appointmentDateEnd,
        result: data,
      );
      if (mounted && requestId == _loadRequestId) {
        setState(() {
          _sourceData = data;
          _data = _applyLocalFilters(data);
        });
        _filtering = false;
        _scrollToTop();
      }
    } on ReferredAppointmentsException {
      if (mounted && requestId == _loadRequestId) {
        setState(() {
          _filtering = false;
          _error =
              'No se pudieron sincronizar las referencias. Intenta nuevamente.';
        });
        if (_data != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se pudo cargar esta página. Intenta nuevamente.',
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted && requestId == _loadRequestId) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _restoreCacheAndRefresh() async {
    final cached = await ReferredAppointmentsCache.load(
      session: _session,
      page: 1,
      status: _status,
      attendance: _attendance,
      creationDateStart: _creationDateStart,
      creationDateEnd: _creationDateEnd,
      appointmentDateStart: _appointmentDateStart,
      appointmentDateEnd: _appointmentDateEnd,
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

  ReferredAppointmentsResult _applyLocalFilters(
    ReferredAppointmentsResult data,
  ) {
    if (!_hasActiveFilters) return data;
    final appointments = data.appointments.where((appointment) {
      if (_status != null && appointment.status != _status) return false;
      if (_attendance != null && appointment.attendance != _attendance) {
        return false;
      }
      if (!_isWithinDates(
        appointment.creationDate,
        _creationDateStart,
        _creationDateEnd,
      )) {
        return false;
      }
      if (!_isWithinDates(
        appointment.appointmentDate,
        _appointmentDateStart,
        _appointmentDateEnd,
      )) {
        return false;
      }
      return true;
    }).toList();
    return ReferredAppointmentsResult(
      total: data.total,
      page: data.page,
      perPage: data.perPage,
      currencySymbol: data.currencySymbol,
      appointments: appointments,
    );
  }

  bool _isWithinDates(String value, DateTime? start, DateTime? end) {
    if (start == null && end == null) return true;
    final date = DateTime.tryParse(value);
    if (date == null) return false;
    final day = DateTime(date.year, date.month, date.day);
    if (start != null &&
        day.isBefore(DateTime(start.year, start.month, start.day))) {
      return false;
    }
    if (end != null && day.isAfter(DateTime(end.year, end.month, end.day))) {
      return false;
    }
    return true;
  }

  Future<ReferredAppointmentsResult> _fetch(int page) async {
    try {
      return await _service.fetch(
        session: _session,
        page: page,
        status: _status,
        attendance: _attendance,
        creationDateStart: _creationDateStart,
        creationDateEnd: _creationDateEnd,
        appointmentDateStart: _appointmentDateStart,
        appointmentDateEnd: _appointmentDateEnd,
      );
    } on ReferredAppointmentsException {
      final refreshed = await const AuthService().refreshSession(_session);
      if (refreshed == null) {
        await SessionStore.clear();
        if (mounted) setState(() => _sessionExpired = true);
        rethrow;
      }
      _session = refreshed;
      await SessionStore.save(refreshed);
      return _service.fetch(
        session: refreshed,
        page: page,
        status: _status,
        attendance: _attendance,
        creationDateStart: _creationDateStart,
        creationDateEnd: _creationDateEnd,
        appointmentDateStart: _appointmentDateStart,
        appointmentDateEnd: _appointmentDateEnd,
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

  void _clear() {
    setState(() {
      _status = null;
      _attendance = null;
      _creationDateStart = null;
      _creationDateEnd = null;
      _appointmentDateStart = null;
      _appointmentDateEnd = null;
    });
    _load(announceFiltering: true);
  }

  Future<void> _pickDate({
    required bool appointmentDate,
    required bool isEnd,
  }) async {
    final current = appointmentDate
        ? (isEnd ? _appointmentDateEnd : _appointmentDateStart)
        : (isEnd ? _creationDateEnd : _creationDateStart);
    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (appointmentDate) {
        if (isEnd) {
          _appointmentDateEnd = selected;
        } else {
          _appointmentDateStart = selected;
        }
      } else {
        if (isEnd) {
          _creationDateEnd = selected;
        } else {
          _creationDateStart = selected;
        }
      }
    });
  }

  String _date(DateTime? value) => value == null
      ? ''
      : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  void _goBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _goBack();
    },
    child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF10264C),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 36,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        centerTitle: true,
        title: const Text(
          'Mis referencias',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            _filterPanel(),
            Expanded(child: _body()),
          ],
        ),
      ),
      bottomNavigationBar: _ReferencesBottomMenu(session: _session),
    ),
  );

  Widget _filterPanel() => Container(
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
                    Expanded(
                      child: Text(
                        _hasActiveFilters
                            ? 'Filtros activos'
                            : 'Filtrar referencias',
                        style: const TextStyle(
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
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _FilterDropdown(
                        label: 'Estado de cita',
                        value: _status,
                        items: const {
                          'pending': 'En Espera',
                          'ok': 'Confirmada',
                          'cancel': 'Cancelada',
                          'rescheduling': 'Reprogramando',
                        },
                        onChanged: (value) => setState(() {
                          _status = value;
                          if (_attendanceIsRestricted) _attendance = null;
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _FilterDropdown(
                        label: 'Estado de asistencia',
                        value: _attendance,
                        items: _attendanceIsRestricted
                            ? const {}
                            : const {
                                'pending': 'En Espera',
                                'yes': 'Sí Asistió',
                                'no': 'No Asistió',
                              },
                        onChanged: (value) => setState(() {
                          _attendance = value;
                          if (value != null) _status = 'ok';
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _ReferenceDateField(
                        label: 'Fecha entrada DESDE',
                        value: _date(_creationDateStart),
                        onTap: () =>
                            _pickDate(appointmentDate: false, isEnd: false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ReferenceDateField(
                        label: 'Fecha entrada HASTA',
                        value: _date(_creationDateEnd),
                        onTap: () =>
                            _pickDate(appointmentDate: false, isEnd: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _ReferenceDateField(
                        label: 'Fecha cita DESDE',
                        value: _date(_appointmentDateStart),
                        onTap: () =>
                            _pickDate(appointmentDate: true, isEnd: false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ReferenceDateField(
                        label: 'Fecha cita HASTA',
                        value: _date(_appointmentDateEnd),
                        onTap: () =>
                            _pickDate(appointmentDate: true, isEnd: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _loading
                            ? null
                            : () {
                                setState(() => _filtersOpen = false);
                                _load(announceFiltering: true);
                              },
                        icon: const Icon(Icons.filter_alt),
                        label: const Text('Filtrar'),
                        style: const ButtonStyle(
                          backgroundColor: WidgetStatePropertyAll(
                            Color(0xFF009FA4),
                          ),
                          foregroundColor: WidgetStatePropertyAll(Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _clear,
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Limpiar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _body() {
    if (_sessionExpired) return _sessionExpiredState();
    if (_filtering) return _filteringState();
    if (_loading && _data == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF009FA4)),
      );
    }
    if (_error != null && _data == null) {
      return _errorState();
    }
    final data = _data;
    if (data == null || data.appointments.isEmpty) {
      return _emptyState();
    }
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
            itemCount: data.appointments.length,
            itemBuilder: (_, index) => _AppointmentCard(
              appointment: data.appointments[index],
              currencySymbol: data.currencySymbol,
            ),
          ),
        ),
        _pagination(data),
      ],
    );
  }

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
            'Tu sesión expiró. Inicia sesión nuevamente para ver las referencias.',
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

  Widget _pagination(ReferredAppointmentsResult data) => Container(
    color: Colors.white,
    child: SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE4EAF4))),
        ),
        padding: const EdgeInsets.fromLTRB(20, 5, 12, 5),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _paginationLabel(
                  page: data.page,
                  perPage: data.perPage,
                  visible: data.appointments.length,
                  total: data.total,
                ),
                style: const TextStyle(fontSize: 15, color: Color(0xFF647194)),
              ),
            ),
            IconButton(
              onPressed: data.page > 1 && !_loading
                  ? () => _load(page: data.page - 1)
                  : null,
              icon: const Icon(Icons.chevron_left, color: Color(0xFF10264C)),
            ),
            Text(
              '${data.page}',
              style: const TextStyle(color: Color(0xFF10264C)),
            ),
            IconButton(
              onPressed: data.hasNext && !_loading
                  ? () => _load(page: data.page + 1)
                  : null,
              icon: const Icon(Icons.chevron_right, color: Color(0xFF10264C)),
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
    if (visible == 0) return 'Mostrando 0 de $total referencias';
    final first = ((page - 1) * perPage) + 1;
    final last = first + visible - 1;
    return 'Mostrando $first–$last de $total referencias';
  }

  Widget _emptyState() => Center(
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
          Icon(Icons.event_busy_outlined, size: 38, color: Color(0xFF24364B)),
          SizedBox(height: 12),
          Text(
            'No se encontraron referencias en la base de datos de citas médicas.',
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

  Widget _errorState() => Center(
    child: Container(
      margin: const EdgeInsets.all(28),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFB9E9DF)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 38,
            color: Color(0xFF24364B),
          ),
          const SizedBox(height: 12),
          const Text(
            'No pudimos actualizar las referencias.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF24364B),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Verifica tu conexión e inténtalo nuevamente.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF53645F)),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _loading ? null : _load,
            style: const ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(Color(0xFF24364B)),
              foregroundColor: WidgetStatePropertyAll(Colors.white),
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );
}

class _ReferenceDateField extends StatelessWidget {
  const _ReferenceDateField({
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
      Text(
        label,
        style: const TextStyle(
          color: Color(0xFF24364B),
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 5),
      Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 19),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      value.isEmpty ? 'Seleccionar' : value,
                      maxLines: 2,
                      softWrap: true,
                      style: TextStyle(
                        color: value.isEmpty
                            ? const Color(0xFF667772)
                            : const Color(0xFF1A1A1A),
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

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final String? value;
  final Map<String, String> items;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: Color(0xFF24364B),
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 5),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: value,
            style: const TextStyle(
              color: Color(0xFF24364B),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            hint: const Text(
              'Todos',
              style: TextStyle(
                color: Color(0xFF24364B),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text(
                  'Todos',
                  style: TextStyle(fontWeight: FontWeight.w400),
                ),
              ),
              ...items.entries.map(
                (entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(
                    entry.value,
                    style: const TextStyle(fontWeight: FontWeight.w400),
                  ),
                ),
              ),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    ],
  );
}

@pragma('vm:entry-point')
class _AppointmentCardOld extends StatelessWidget {
  const _AppointmentCardOld({required this.appointment});
  final ReferralAppointment appointment;
  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFD2F1FB),
        foregroundColor: Color(0xFF24364B),
        child: Icon(Icons.medical_information_outlined),
      ),
      title: Text(
        appointment.patientName.isEmpty ? 'Paciente' : appointment.patientName,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${appointment.clinic}\nCita: ${appointment.appointmentDate}\n${_statusLabel(appointment.status)} · ${_attendanceLabel(appointment.attendance)}',
      ),
      isThreeLine: true,
    ),
  );
}

String _statusLabel(String value) => switch (value) {
  'ok' => 'Confirmada',
  'cancel' => 'Cancelada',
  'rescheduling' => 'Reprogramando',
  _ => 'En espera',
};
String _attendanceLabel(String value) => switch (value) {
  'yes' => 'Sí Asistió',
  'no' => 'No Asistió',
  _ => 'En Espera',
};

class _AppointmentCard extends StatefulWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.currencySymbol,
  });
  final ReferralAppointment appointment;
  final String currencySymbol;
  @override
  State<_AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends State<_AppointmentCard> {
  bool _expanded = false;
  ReferralAppointment get appointment => widget.appointment;

  String get _displayStatus {
    return switch (appointment.attendance) {
      'yes' => 'Asistió',
      'no' => 'No asistió',
      _ => switch (appointment.status) {
        'cancel' => 'Cancelado',
        'ok' => 'Confirmada',
        'rescheduling' => 'Reprogramando',
        _ => 'Pendiente',
      },
    };
  }

  Color get _statusColor => switch (appointment.attendance) {
    'yes' => const Color(0xFF07843F),
    'no' => const Color(0xFFE22D2D),
    _ => switch (appointment.status) {
      'cancel' => const Color(0xFFA86600),
      'ok' => const Color(0xFF07843F),
      _ => const Color(0xFF1B65D8),
    },
  };

  Color get _statusBackground => switch (appointment.attendance) {
    'yes' => const Color(0xFFE0F6E8),
    'no' => const Color(0xFFFFE7E7),
    _ => switch (appointment.status) {
      'cancel' => const Color(0xFFFFF2D9),
      'ok' => const Color(0xFFE0F6E8),
      _ => const Color(0xFFE7EFFF),
    },
  };
  String _date(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value.isEmpty ? 'No disponible' : value;
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${date.year}-${months[date.month - 1]}-${date.day.toString().padLeft(2, '0')}';
  }

  String _money(num value) => value
      .toStringAsFixed(2)
      .replaceAllMapped(RegExp(r'(?<!^)(?=(\d{3})+(?:\.|$))'), (_) => ',');
  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 10),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Color(0xFFE4EAF4)),
    ),
    child: InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 31,
                  backgroundColor: _statusBackground,
                  foregroundColor: _statusColor,
                  child: const Icon(Icons.person_rounded, size: 40),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    appointment.patientName.isEmpty
                        ? 'Paciente'
                        : appointment.patientName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      color: Color(0xFF10264C),
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: _statusBackground,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    _displayStatus,
                    style: TextStyle(
                      color: _statusColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: Color(0xFF647194),
                ),
              ],
            ),
            const SizedBox(height: 9),
            if (_expanded && appointment.id.isNotEmpty)
              Text(
                'Reserva #${appointment.id}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            _InfoLine(label: 'Clínica', value: appointment.clinic),
            if (_expanded && appointment.location.isNotEmpty)
              _InfoLine(
                label: 'Ubicación',
                value: appointment.location,
                icon: Icons.location_on_outlined,
              ),
            _InfoLine(
              label: 'Fecha entrada',
              value: _date(appointment.creationDate),
            ),
            _InfoLine(
              label: 'Fecha cita',
              value: _date(appointment.appointmentDate),
            ),
            if (_expanded)
              Text(
                '${_statusLabel(appointment.status)} · ${_attendanceLabel(appointment.attendance)}',
                style: const TextStyle(color: Color(0xFF53645F)),
              ),
            if (_expanded) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 11),
                child: Divider(height: 1, color: Color(0xFFE1ECE9)),
              ),
              if (appointment.finalPrice case final price?)
                _InfoLine(
                  label: 'Precio final',
                  value: '${widget.currencySymbol}${_money(price)}',
                  bold: true,
                ),
              if (appointment.services.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(top: 11, bottom: 8),
                  child: Divider(height: 1, color: Color(0xFFE1ECE9)),
                ),
                const Text(
                  'Exámenes médicos',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                ...appointment.services.map(
                  (service) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(switch (service.price) {
                      final price? =>
                        '${service.name}  →  ${widget.currencySymbol}${_money(price)}',
                      null => service.name,
                    }),
                  ),
                ),
              ],
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.touch_app_outlined,
                      size: 16,
                      color: Color(0xFF53645F),
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Toca para ver detalles',
                      style: TextStyle(fontSize: 12, color: Color(0xFF53645F)),
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

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
    this.icon,
    this.bold = false,
  });
  final String label, value;
  final IconData? icon;
  final bool bold;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: const Color(0xFF24364B)),
          const SizedBox(width: 4),
        ],
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ReferencesBottomMenu extends StatelessWidget {
  const _ReferencesBottomMenu({required this.session});

  final UserSession session;

  Future<void> _copyInviteLink(BuildContext context) async {
    final link = session.inviteLink?.trim() ?? '';
    final message = link.isEmpty
        ? 'No hay un enlace de invitación disponible.'
        : 'El enlace de invitación está listo para compartir.';
    if (link.isNotEmpty) await Clipboard.setData(ClipboardData(text: link));
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          link.isEmpty ? 'Invitación no disponible' : 'Enlace copiado',
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
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
            child: _ReferencesMenuItem(
              label: 'Enviar\nmensaje',
              asset: 'assets/svg/health-checkup.svg',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const _ReferencesMenuDivider(),
          Expanded(
            child: _ReferencesMenuItem(
              label: 'Mis enviados',
              asset: 'assets/svg/Icono de enviados - líneas celeste.svg',
              onPressed: () => Navigator.of(context).pushReplacement(
                appPageRoute(SentMessagesPage(session: session)),
              ),
            ),
          ),
          const _ReferencesMenuDivider(),
          Expanded(
            child: _ReferencesMenuItem(
              label: 'Mis referencias',
              asset: 'assets/svg/Icono de referencias - líneas celestes.svg',
              selected: true,
              onPressed: () {},
            ),
          ),
          const _ReferencesMenuDivider(),
          Expanded(
            child: _ReferencesMenuItem(
              label: 'Invitar a un amigo',
              asset: 'assets/svg/Icono de invitar amigo - celeste.svg',
              onPressed: () => _copyInviteLink(context),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ReferencesMenuDivider extends StatelessWidget {
  const _ReferencesMenuDivider();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 42,
    child: VerticalDivider(color: Color(0xFFD5DEF0)),
  );
}

class _ReferencesMenuItem extends StatelessWidget {
  const _ReferencesMenuItem({
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
