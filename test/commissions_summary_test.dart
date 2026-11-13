import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:chequea_app/features/auth/models/user_session.dart';
import 'package:chequea_app/features/home/pages/commissions_page.dart';
import 'package:chequea_app/features/home/services/commissions_service.dart';

void main() {
  for (final width in [320.0, 360.0, 440.0]) {
    testWidgets('el resumen mantiene tres columnas a $width px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: CommissionsPage(
            session: UserSession(
              username: 'test',
              country: 'Panamá',
              isChequeandomeAgent: false,
              refreshToken: 'test',
              accessToken: 'test',
            ),
            service: CommissionsService(client: _CommissionsHttpClient()),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Resumen de comisiones'));

      final title = tester.getTopLeft(find.text('Reservas asistidas'));
      final formula = tester.getTopLeft(find.text(r'$3000.00 x 10%'));
      final amount = tester.getTopLeft(find.text(r'$300.00').first);
      final firstFormula = tester.getTopLeft(find.text(r'500 x $0.50'));
      expect((title.dy - formula.dy).abs(), lessThan(8));
      expect((title.dy - amount.dy).abs(), lessThan(8));
      expect((firstFormula.dx - formula.dx).abs(), lessThan(1));
      expect(find.text(r'$650.00'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}

class _CommissionsHttpClient extends http.BaseClient {
  var _requestNumber = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = _requestNumber++ == 0
        ? '''{
          "sent_chequeas": {"total_sent": 500, "comm_amount_per_sent": 0.5, "total_commission": 250},
          "ref_attended_appts": {"total_price": 3000, "pct_per_appt": 10, "total_commission": 300},
          "ref_invs_attended_appts": {"total_price": 6500, "pct_per_appt": 10, "total_commission": 650},
          "grand_total_commission": 1200
        }'''
        : '[]';
    return http.StreamedResponse(
      Stream.value(body.codeUnits),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
}
