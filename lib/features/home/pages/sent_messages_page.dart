import 'package:flutter/material.dart';

import '../../auth/models/user_session.dart';
import '../../auth/services/auth_service.dart';
import '../../auth/services/session_store.dart';
import '../services/sent_messages_service.dart';

class SentMessagesPage extends StatefulWidget {
  const SentMessagesPage({super.key, required this.session});
  final UserSession session;

  @override
  State<SentMessagesPage> createState() => _SentMessagesPageState();
}

class _SentMessagesPageState extends State<SentMessagesPage> {
  final _cellphone = TextEditingController();
  final _service = const SentMessagesService();
  late UserSession _session;
  DateTime? _startDate;
  DateTime? _endDate;
  SentMessagesResult? _data;
  SentMessagesResult? _sourceData;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _restoreCacheAndRefresh();
  }

  @override
  void dispose() {
    _cellphone.dispose();
    super.dispose();
  }

  Future<void> _load({int page = 1}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (_sourceData != null) _data = _applyLocalFilters(_sourceData!);
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
      if (mounted) setState(() => _loading = false);
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
      final refreshed = await const AuthService().refreshSession(_session);
      if (refreshed == null) rethrow;
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
    final selected = await showDatePicker(
      context: context,
      initialDate: start
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
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

  Future<void> _clearFilters() async {
    setState(() {
      _startDate = null;
      _endDate = null;
      _cellphone.clear();
    });
    final cached = await SentMessagesCache.load(
      session: _session,
      page: 1,
      startDate: null,
      endDate: null,
      cellphone: null,
    );
    if (mounted && cached != null) {
      setState(() {
        _sourceData = cached;
        _data = cached;
      });
    }
    await _load();
  }

  SentMessagesResult _applyLocalFilters(SentMessagesResult data) {
    final phone = _cellphone.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (_startDate == null && _endDate == null && phone.isEmpty) return data;
    final messages = data.messages.where((message) {
      final messagePhone = message.cellphone.replaceAll(RegExp(r'[^0-9]'), '');
      if (phone.isNotEmpty && messagePhone != phone) return false;
      final date = DateTime.tryParse(message.createdDate ?? '');
      if (_startDate != null && (date == null || date.isBefore(_startDate!))) {
        return false;
      }
      if (_endDate != null &&
          (date == null ||
              !date.isBefore(_endDate!.add(const Duration(days: 1))))) {
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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF47D1B6),
    appBar: AppBar(
      backgroundColor: const Color(0xFF47D1B6),
      foregroundColor: const Color(0xFF24364B),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 0,
      title: const FittedBox(
        alignment: Alignment.centerLeft,
        fit: BoxFit.scaleDown,
        child: Text(
          'Mensajes de referencia enviados',
          maxLines: 1,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
    ),
    body: SafeArea(top: false, bottom: false, child: _body()),
  );

  Widget _body() {
    final data = _data;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _filters()),
        const SliverToBoxAdapter(
          child: Divider(height: 1, color: Color(0xFF24364B)),
        ),
        if (_loading && data == null)
          const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          )
        else if (_error != null)
          SliverFillRemaining(child: Center(child: Text(_error!)))
        else if (data == null || data.messages.isEmpty)
          const SliverFillRemaining(
            child: Center(
              child: Text(
                'No se encontraron mensajes.',
                style: TextStyle(color: Color(0xFF24364B)),
              ),
            ),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            sliver: SliverList.builder(
              itemCount: data.messages.length,
              itemBuilder: (_, index) => _MessageItem(
                message: data.messages[index],
                number: index + 1 + ((data.page - 1) * data.perPage),
              ),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _pagination(data),
            ),
          ),
        ],
      ],
    );
  }

  Widget _filters() => Padding(
    padding: const EdgeInsets.all(16),
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
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _cellphone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.phone),
                  hintText: 'Celular',
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              style: const ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(Color(0xFF24364B)),
                foregroundColor: WidgetStatePropertyAll(Colors.white),
              ),
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.filter_alt),
              label: const Text('Filtrar'),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white, width: 1.4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              shape: const StadiumBorder(),
            ),
            onPressed: _loading ? null : _clearFilters,
            icon: const Icon(Icons.restart_alt, size: 18),
            label: const Text('Limpiar filtros'),
          ),
        ),
      ],
    ),
  );

  Widget _pagination(SentMessagesResult data) => Container(
    decoration: const BoxDecoration(
      color: Color(0xFF24364B),
      border: Border(top: BorderSide(color: Colors.white)),
    ),
    padding: const EdgeInsets.fromLTRB(16, 7, 10, 7),
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
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
        ),
        IconButton(
          onPressed: data.page > 1 && !_loading
              ? () => _load(page: data.page - 1)
              : null,
          icon: const Icon(Icons.chevron_left, color: Colors.white),
        ),
        Text('${data.page}', style: const TextStyle(color: Colors.white)),
        IconButton(
          onPressed: data.hasNext && !_loading
              ? () => _load(page: data.page + 1)
              : null,
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
    if (visible == 0) return 'Mostrando 0 de $total mensajes';
    final first = ((page - 1) * perPage) + 1;
    final last = first + visible - 1;
    return 'Mostrando $first–$last de $total mensajes';
  }
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
        padding: const EdgeInsets.only(left: 4, bottom: 5),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF24364B),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Color(0xFF24364B)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      value.isEmpty ? 'Seleccionar' : value,
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
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF47D1B6)),
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
  String _formattedDate(String? value) {
    final date = value == null ? null : DateTime.tryParse(value);
    if (date == null) {
      return value?.isNotEmpty == true ? value! : 'Fecha no disponible';
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
    final sender = message.referrerName.isEmpty
        ? message.referrerUsername
        : message.referrerName;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF47D1B6)),
      ),
      child: InkWell(
        onTap: expandable ? () => setState(() => _expanded = !_expanded) : null,
        borderRadius: BorderRadius.circular(14),
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
                      '${widget.number}',
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
                ),
              if (expandable)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 28),
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
  const _DateBadge({required this.date, this.time});
  final String date;
  final String? time;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 105),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFD2F1FB),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          date,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        ),
        if (time != null && time!.isNotEmpty)
          Text(
            time!,
            style: const TextStyle(fontSize: 10, color: Color(0xFF24364B)),
          ),
      ],
    ),
  );
}
