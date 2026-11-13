import 'package:flutter/material.dart';

import '../../auth/models/user_session.dart';
import '../services/commissions_service.dart';
import '../../mobile/home/pages/commissions_page_mobile.dart';

class CommissionsPage extends StatelessWidget {
  const CommissionsPage({super.key, required this.session, this.service});

  final UserSession session;
  final CommissionsService? service;

  @override
  Widget build(BuildContext context) =>
      MobileCommissionsPage(session: session, service: service);
}
