import 'package:flutter/material.dart';

import '../../auth/models/user_session.dart';
import '../../mobile/home/pages/sent_messages_page_mobile.dart';

class SentMessagesPage extends StatelessWidget {
  const SentMessagesPage({super.key, required this.session});

  final UserSession session;

  @override
  Widget build(BuildContext context) => MobileSentMessagesPage(session: session);
}
