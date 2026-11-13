import 'package:flutter/material.dart';

import '../../auth/models/user_session.dart';
import '../../mobile/home/pages/home_page_mobile.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.session,
    this.onSessionUpdated,
    this.onSessionExpired,
  });

  final UserSession session;
  final ValueChanged<UserSession>? onSessionUpdated;
  final Future<void> Function()? onSessionExpired;

  @override
  Widget build(BuildContext context) => MobileHomePage(
    session: session,
    onSessionUpdated: onSessionUpdated,
    onSessionExpired: onSessionExpired,
  );
}
