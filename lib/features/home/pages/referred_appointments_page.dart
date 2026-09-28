import 'package:flutter/material.dart';

import '../../auth/models/user_session.dart';
import '../../auth/services/auth_service.dart';
import '../../auth/services/session_store.dart';
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
  late UserSession _session;
  String? _status;
  String? _attendance;
  ReferredAppointmentsResult? _data;
  ReferredAppointmentsResult? _sourceData;
  bool _loading = true;
  String? _error;
  bool _filtersOpen = false;
  bool _filtering = false;
  int _loadRequestId = 0;

  bool get _hasActiveFilters => _status != null || _attendance != null;
  bool get _attendanceIsRestricted =>
      _status == 'cancel' || _status == 'pending' || _status == 'rescheduling';

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _restoreCacheAndRefresh();
  }

  Future<void> _load({int page = 1, bool announceFiltering = false}) async {
    final requestId = ++_loadRequestId;
    setState(() {
      _loading = true;
      _error = null;
      _filtering = announceFiltering;
      if (_sourceData != null) _data = _applyLocalFilters(_sourceData!);
    });
    try {
      final cached = await ReferredAppointmentsCache.load(
        session: _session,
        page: page,
        status: _status,
        attendance: _attendance,
      );
      if (mounted && cached != null && requestId == _loadRequestId) {
        setState(() {
          _sourceData = cached;
          _data = _applyLocalFilters(cached);
          _loading = false;
        });
      }
      final data = await _fetch(page);
      await ReferredAppointmentsCache.save(
        session: _session,
        page: page,
        status: _status,
        attendance: _attendance,
        result: data,
      );
      if (mounted && requestId == _loadRequestId) {
        setState(() {
          _sourceData = data;
          _data = _applyLocalFilters(data);
        });
        _filtering = false;
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

  Future<ReferredAppointmentsResult> _fetch(int page) async {
    try {
      return await _service.fetch(
        session: _session,
        page: page,
        status: _status,
        attendance: _attendance,
      );
    } on ReferredAppointmentsException {
      final refreshed = await const AuthService().refreshSession(_session);
      if (refreshed == null) rethrow;
      _session = refreshed;
      await SessionStore.save(refreshed);
      return _service.fetch(
        session: refreshed,
        page: page,
        status: _status,
        attendance: _attendance,
      );
    }
  }

  void _clear() {
    setState(() {
      _status = null;
      _attendance = null;
    });
    _load(announceFiltering: true);
  }

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
      backgroundColor: const Color(0xFF47D1B6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF47D1B6),
        foregroundColor: const Color(0xFF24364B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        title: const Text(
          'Mis referencias',
          style: TextStyle(fontWeight: FontWeight.w600),
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
    ),
  );

  Widget _filterPanel() => Container(
    margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .18),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white70),
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
                        label: 'Estado',
                        value: _status,
                        items: const {
                          'pending': 'En espera',
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
                        label: 'Asistencia',
                        value: _attendance,
                        items: _attendanceIsRestricted
                            ? const {}
                            : const {
                                'pending': 'En espera',
                                'yes': 'Sí asistió',
                                'no': 'No asistió',
                              },
                        onChanged: (value) =>
                            setState(() => _attendance = value),
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
                            Color(0xFF24364B),
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
    if (_filtering) return _filteringState();
    if (_loading && _data == null) {
      return _emptyState();
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
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
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

  Widget _pagination(ReferredAppointmentsResult data) => Container(
    color: const Color(0xFF24364B),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
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
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        IconButton(
          onPressed: data.page > 1 ? () => _load(page: data.page - 1) : null,
          icon: const Icon(Icons.chevron_left, color: Colors.white),
        ),
        Text('${data.page}', style: const TextStyle(color: Colors.white)),
        IconButton(
          onPressed: data.hasNext ? () => _load(page: data.page + 1) : null,
          icon: const Icon(Icons.chevron_right, color: Colors.white),
        ),
      ],
    ),
  );

  String _paginationLabel({
    required int page,
    required int perPage,
    required int visible,
    required int total,
  }) {
    if (visible == 0) return 'Mostrando 0 de $total';
    final first = ((page - 1) * perPage) + 1;
    final last = first + visible - 1;
    return 'Mostrando $first–$last de $total';
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
            'Aún no tienes referencias registradas.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF24364B),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Cuando un paciente genere una cita desde tu referencia, aparecerá aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF53645F), height: 1.3),
          ),
        ],
      ),
    ),
  );

  Widget _filteringState() => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: Colors.white),
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
            hint: const Text('Todos'),
            items: [
              const DropdownMenuItem<String>(value: null, child: Text('Todos')),
              ...items.entries.map(
                (entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
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

// Kept temporarily to preserve the legacy layout during hot reload.
// ignore: unused_element
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
  'yes' => 'Asistió',
  'no' => 'No asistió',
  _ => 'Asistencia pendiente',
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
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: Color(0xFFB9E9DF)),
    ),
    child: InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFD2F1FB),
                  foregroundColor: Color(0xFF24364B),
                  child: Icon(Icons.medical_information_outlined),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    appointment.patientName.isEmpty
                        ? 'Paciente'
                        : appointment.patientName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: const Color(0xFF24364B),
                ),
              ],
            ),
            const SizedBox(height: 9),
            _InfoLine(label: 'Clínica', value: appointment.clinic),
            _InfoLine(label: 'Entrada', value: _date(appointment.creationDate)),
            _InfoLine(label: 'Cita', value: _date(appointment.appointmentDate)),
            Text(
              '${_statusLabel(appointment.status)} · ${_attendanceLabel(appointment.attendance)}',
              style: const TextStyle(color: Color(0xFF53645F)),
            ),
            if (_expanded) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 11),
                child: Divider(height: 1, color: Color(0xFFE1ECE9)),
              ),
              if (appointment.id.isNotEmpty)
                _InfoLine(label: 'Reserva', value: '#${appointment.id}'),
              if (appointment.location.isNotEmpty)
                _InfoLine(
                  label: 'Ubicación',
                  value: appointment.location,
                  icon: Icons.location_on_outlined,
                ),
              if (appointment.finalPrice != null)
                _InfoLine(
                  label: 'Precio final',
                  value:
                      '${widget.currencySymbol}${_money(appointment.finalPrice!)}',
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
                    child: Text(
                      service.price == null
                          ? service.name
                          : '${service.name}  →  ${widget.currencySymbol}${_money(service.price!)}',
                    ),
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
