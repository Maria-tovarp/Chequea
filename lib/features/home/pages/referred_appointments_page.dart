import 'package:flutter/material.dart';

import '../../auth/models/user_session.dart';
import '../../mobile/home/pages/referred_appointments_page_mobile.dart';

class ReferredAppointmentsPage extends StatelessWidget {
  const ReferredAppointmentsPage({super.key, required this.session});

  final UserSession session;

  @override
  Widget build(BuildContext context) =>
      MobileReferredAppointmentsPage(session: session);
}
