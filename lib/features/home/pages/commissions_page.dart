import 'package:flutter/material.dart';

import '../../../core/navigation/app_page_route.dart';
import '../../auth/models/user_session.dart';
import '../../auth/pages/login_page.dart';
import '../../auth/services/auth_service.dart';
import '../../auth/services/session_store.dart';
import 'home_page.dart';
import 'referred_appointments_page.dart';
import 'sent_messages_page.dart';
import '../widgets/app_bottom_menu.dart';
import '../widgets/app_notice_dialog.dart';
import '../services/commissions_service.dart';

class CommissionsPage extends StatefulWidget {
  const CommissionsPage({super.key, required this.session});

  final UserSession session;

  @override
  State<CommissionsPage> createState() => _CommissionsPageState();
}

class _CommissionsPageState extends State<CommissionsPage> {
  final _service = const CommissionsService();
  late UserSession _session;
  CommissionsData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _fetch();
      if (mounted) setState(() => _data = data);
    } on CommissionsException {
      if (mounted)
        setState(() => _error = 'No fue posible cargar tus comisiones.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<CommissionsData> _fetch() async {
    try {
      return await _service.fetch(_session);
    } on CommissionsException catch (error) {
      if (error.sessionExpired) {
        await SessionStore.clear();
        if (mounted) _goToLogin();
        rethrow;
      }
      final refresh = await const AuthService().refreshSession(_session);
      if (refresh.session == null) {
        if (refresh.invalid) {
          await SessionStore.clear();
          if (mounted) _goToLogin();
        }
        rethrow;
      }
      _session = refresh.session!;
      await SessionStore.save(_session);
      return _service.fetch(_session);
    }
  }

  void _goToLogin() => Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginPage()),
    (route) => false,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF10264C),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        tooltip: 'Volver',
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 23),
        onPressed: () => Navigator.of(
          context,
        ).pushReplacement(appPageRoute(HomePage(session: _session))),
      ),
      title: const Text(
        'Mis comisiones',
        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
      ),
      actions: const [HeaderNoticeActions()],
    ),
    body: SafeArea(
      top: false,
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loading && _data == null)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_data != null) ...[
              _EarningsCard(total: _data!.grandTotal),
              const SizedBox(height: 14),
              _CommissionSummaryCard(
                items: _summaryFrom(_data!),
                total: _data!.grandTotal,
              ),
              const SizedBox(height: 14),
              _PreviousPaymentsCard(payments: _paymentsFrom(_data!)),
            ] else
              _ErrorState(
                message: _error ?? 'No fue posible cargar tus comisiones.',
                onRetry: _load,
              ),
          ],
        ),
      ),
    ),
    bottomNavigationBar: AppBottomMenu(
      selected: AppBottomMenuSection.commissions,
      onHome: () => Navigator.of(
        context,
      ).pushReplacement(appPageRoute(HomePage(session: _session))),
      onSent: () => Navigator.of(
        context,
      ).pushReplacement(appPageRoute(SentMessagesPage(session: _session))),
      onReferences: () => Navigator.of(context).pushReplacement(
        appPageRoute(ReferredAppointmentsPage(session: _session)),
      ),
      onCommissions: () {},
    ),
  );
}

class _EarningsCard extends StatelessWidget {
  const _EarningsCard({required this.total});

  final num total;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE8FAF8), Color(0xFFF4FBFB)],
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: const BoxDecoration(
            color: Color(0xFFD6F4EF),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: CircleAvatar(
              radius: 28,
              backgroundColor: Color(0xFF00A47E),
              child: Text(
                r'$',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total ganado',
                style: TextStyle(color: Color(0xFF647194), fontSize: 15),
              ),
              SizedBox(height: 2),
              Text(
                _money(total),
                style: const TextStyle(
                  color: Color(0xFF009FA4),
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2),
              const Text(
                'Período actual',
                style: TextStyle(color: Color(0xFF647194), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CommissionSummaryCard extends StatelessWidget {
  const _CommissionSummaryCard({required this.items, required this.total});

  final List<_CommissionItem> items;
  final num total;

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: 'Resumen de comisiones',
    child: Column(
      children: [
        for (final item in items) ...[
          _CommissionRow(item: item),
          const Divider(height: 13, color: Color(0xFFE2EAF4)),
        ],
        Row(
          children: [
            Text(
              'Total',
              style: TextStyle(
                color: Color(0xFF10264C),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            Spacer(),
            Text(
              _money(total),
              style: const TextStyle(
                color: Color(0xFF008F95),
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _CommissionRow extends StatelessWidget {
  const _CommissionRow({required this.item});

  final _CommissionItem item;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          flex: 14,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              item.title,
              maxLines: 1,
              style: const TextStyle(
                color: Color(0xFF10264C),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          flex: 8,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              item.formula,
              maxLines: 1,
              style: const TextStyle(color: Color(0xFF647194), fontSize: 11),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          flex: 7,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              item.amount,
              maxLines: 1,
              style: const TextStyle(
                color: Color(0xFF008F95),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _MembershipRow extends StatelessWidget {
  const _MembershipRow();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final showBadgeInline = constraints.maxWidth >= 340;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  flex: 14,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Costo de membresía',
                      maxLines: 1,
                      style: TextStyle(
                        color: Color(0xFF10264C),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                const Expanded(
                  flex: 8,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      r'$0.00',
                      maxLines: 1,
                      style: TextStyle(color: Color(0xFF647194), fontSize: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  flex: 7,
                  child: showBadgeInline
                      ? const SizedBox(
                          height: 22,
                          child: OverflowBox(
                            alignment: Alignment.centerRight,
                            minWidth: 0,
                            maxWidth: 120,
                            child: _MembershipBadge(),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
            if (!showBadgeInline) ...[
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerRight,
                child: _MembershipBadge(),
              ),
            ],
          ],
        );
      },
    ),
  );
}

class _MembershipBadge extends StatelessWidget {
  const _MembershipBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFDCEBFF),
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Text(
      'Doctor embajador',
      maxLines: 1,
      style: TextStyle(
        color: Color(0xFF1967D2),
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _PreviousPaymentsCard extends StatelessWidget {
  const _PreviousPaymentsCard({required this.payments});

  final List<_PreviousPayment> payments;

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: 'Pagos anteriores',
    child: payments.isEmpty
        ? const Text(
            'Aún no tienes pagos emitidos.',
            style: TextStyle(color: Color(0xFF647194), fontSize: 13),
          )
        : Column(
            children: [
              for (final payment in payments) ...[
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    color: Color(0xFF647194),
                    size: 21,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      payment.month,
                      style: const TextStyle(
                        color: Color(0xFF435678),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    payment.amount,
                    style: const TextStyle(
                      color: Color(0xFF435678),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          if (payment != payments.last)
            const Divider(height: 1, color: Color(0xFFE2EAF4)),
              ],
            ],
          ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE0E8F3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF10264C),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

class _CommissionItem {
  const _CommissionItem(this.title, this.formula, this.amount);

  final String title;
  final String formula;
  final String amount;
}

class _PreviousPayment {
  const _PreviousPayment(this.month, this.amount);

  final String month;
  final String amount;
}

List<_CommissionItem> _summaryFrom(CommissionsData data) => [
  _CommissionItem(
    'Enlaces enviados',
    '${data.sentChequeas.totalSent} x ${_money(data.sentChequeas.amountPerSent)}',
    _money(data.sentChequeas.total),
  ),
  _CommissionItem(
    'Reservas asistidas',
    '${_money(data.refAttendedAppointments.totalPrice)} x ${_percent(data.refAttendedAppointments.percentage)}',
    _money(data.refAttendedAppointments.total),
  ),
  _CommissionItem(
    'Reservas de mis invitados',
    '${_money(data.invitedReferrersAttendedAppointments.totalPrice)} x ${_percent(data.invitedReferrersAttendedAppointments.percentage)}',
    _money(data.invitedReferrersAttendedAppointments.total),
  ),
];

List<_PreviousPayment> _paymentsFrom(CommissionsData data) => data.payments
    .map(
      (payment) => _PreviousPayment(
        '${_monthName(payment.month)} ${payment.year}',
        _money(payment.total),
      ),
    )
    .toList();

String _money(num value) => r'$' + value.toStringAsFixed(2);
String _percent(num value) =>
    '${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}%';
String _monthName(int month) => const [
  '',
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
][month.clamp(1, 12)];

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    ),
  );
}
