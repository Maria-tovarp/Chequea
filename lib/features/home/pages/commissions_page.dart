import 'package:flutter/material.dart';

import '../../../core/navigation/app_page_route.dart';
import '../../auth/models/user_session.dart';
import 'home_page.dart';
import 'referred_appointments_page.dart';
import 'sent_messages_page.dart';
import '../widgets/app_bottom_menu.dart';
import '../widgets/app_notice_dialog.dart';

class CommissionsPage extends StatelessWidget {
  const CommissionsPage({super.key, required this.session});

  final UserSession session;

  static const _summary = <_CommissionItem>[
    _CommissionItem('Enlaces enviados', r'500 x $0.50', r'$250.00'),
    _CommissionItem('Reservas asistidas', r'$2,000 x 5%', r'$100.00'),
    _CommissionItem('Reservas de mis amigos', r'$3,000 x 10%', r'$300.00'),
  ];

  static const _payments = <_PreviousPayment>[
    _PreviousPayment('Agosto', r'$520.00'),
    _PreviousPayment('Julio', r'$480.00'),
    _PreviousPayment('Junio', r'$300.00'),
    _PreviousPayment('Mayo', r'$225.00'),
  ];

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
        ).pushReplacement(appPageRoute(HomePage(session: session))),
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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _EarningsCard(),
            const SizedBox(height: 18),
            _CommissionSummaryCard(items: _summary),
            const SizedBox(height: 18),
            _PreviousPaymentsCard(
              payments: _payments,
              onTap: (payment) => showAppNoticeDialog(
                context,
                message:
                    'El pago de ${payment.month} por ${payment.amount} fue procesado correctamente.',
              ),
            ),
          ],
        ),
      ),
    ),
    bottomNavigationBar: AppBottomMenu(
      selected: AppBottomMenuSection.commissions,
      onHome: () => Navigator.of(
        context,
      ).pushReplacement(appPageRoute(HomePage(session: session))),
      onSent: () => Navigator.of(
        context,
      ).pushReplacement(appPageRoute(SentMessagesPage(session: session))),
      onReferences: () => Navigator.of(context).pushReplacement(
        appPageRoute(ReferredAppointmentsPage(session: session)),
      ),
      onCommissions: () {},
    ),
  );
}

class _EarningsCard extends StatelessWidget {
  const _EarningsCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE8FAF8), Color(0xFFF4FBFB)],
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 92,
          height: 92,
          decoration: const BoxDecoration(
            color: Color(0xFFD6F4EF),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: CircleAvatar(
              radius: 32,
              backgroundColor: Color(0xFF00A47E),
              child: Text(
                r'$',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 45,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total ganado',
                style: TextStyle(color: Color(0xFF647194), fontSize: 17),
              ),
              SizedBox(height: 2),
              Text(
                r'$650.00',
                style: TextStyle(
                  color: Color(0xFF009FA4),
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2),
              Text(
                '1 septiembre - 19 septiembre',
                style: TextStyle(color: Color(0xFF647194), fontSize: 12),
              ),
              SizedBox(height: 8),
              _StatusPill(),
            ],
          ),
        ),
      ],
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1D9),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Text(
      'Pendiente',
      style: TextStyle(
        color: Color(0xFFC76A00),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _CommissionSummaryCard extends StatelessWidget {
  const _CommissionSummaryCard({required this.items});

  final List<_CommissionItem> items;

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: 'Resumen de comisiones',
    child: Column(
      children: [
        for (final item in items) ...[
          _CommissionRow(item: item),
          const Divider(height: 20, color: Color(0xFFE2EAF4)),
        ],
        const _MembershipRow(),
        const Divider(height: 28, color: Color(0xFFE2EAF4)),
        const Row(
          children: [
            Text(
              'Total',
              style: TextStyle(
                color: Color(0xFF10264C),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            Spacer(),
            Text(
              r'$650.00',
              style: TextStyle(
                color: Color(0xFF008F95),
                fontSize: 25,
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
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        flex: 12,
        child: Text(
          item.title,
          style: const TextStyle(
            color: Color(0xFF10264C),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      Expanded(
        flex: 10,
        child: Text(
          item.formula,
          style: const TextStyle(color: Color(0xFF647194), fontSize: 13),
        ),
      ),
      Expanded(
        flex: 7,
        child: Text(
          item.amount,
          textAlign: TextAlign.end,
          style: const TextStyle(
            color: Color(0xFF008F95),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  );
}

class _MembershipRow extends StatelessWidget {
  const _MembershipRow();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(
        flex: 12,
        child: Text(
          'Costo de membresía',
          style: TextStyle(
            color: Color(0xFF10264C),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      const Expanded(
        flex: 10,
        child: Text(
          r'$0.00',
          style: TextStyle(color: Color(0xFF647194), fontSize: 13),
        ),
      ),
      Expanded(
        flex: 9,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFDCEBFF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text(
            'Doctor embajador',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF1967D2),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ],
  );
}

class _PreviousPaymentsCard extends StatelessWidget {
  const _PreviousPaymentsCard({required this.payments, required this.onTap});

  final List<_PreviousPayment> payments;
  final ValueChanged<_PreviousPayment> onTap;

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: 'Pagos anteriores',
    child: Column(
      children: [
        for (final payment in payments) ...[
          InkWell(
            onTap: () => onTap(payment),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    color: Color(0xFF647194),
                    size: 28,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      payment.month,
                      style: const TextStyle(
                        color: Color(0xFF435678),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    payment.amount,
                    style: const TextStyle(
                      color: Color(0xFF435678),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF647194),
                    size: 28,
                  ),
                ],
              ),
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
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE0E8F3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF10264C),
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 22),
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
