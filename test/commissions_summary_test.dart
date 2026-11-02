import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chequea_app/features/auth/models/user_session.dart';
import 'package:chequea_app/features/home/pages/commissions_page.dart';

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
        const MaterialApp(
          home: CommissionsPage(
            session: UserSession(
              username: 'test',
              country: 'Panamá',
              isChequeandomeAgent: false,
              refreshToken: 'test',
              accessToken: 'test',
            ),
          ),
        ),
      );

      await tester.ensureVisible(find.text('Resumen de comisiones'));
      await tester.pumpAndSettle();

      final title = tester.getTopLeft(find.text('Reservas de mis amigos'));
      final formula = tester.getTopLeft(find.text(r'$3,000 x 10%'));
      final amount = tester.getTopLeft(find.text(r'$300.00').first);
      final firstFormula = tester.getTopLeft(find.text(r'500 x $0.50'));
      final membershipCost = tester.getTopLeft(find.text(r'$0.00'));
      expect((title.dy - formula.dy).abs(), lessThan(8));
      expect((title.dy - amount.dy).abs(), lessThan(8));
      expect((firstFormula.dx - membershipCost.dx).abs(), lessThan(1));
      final badge = tester.getTopLeft(find.text('Doctor embajador'));
      if (width < 404) {
        expect(badge.dy, greaterThan(membershipCost.dy));
      } else {
        expect((badge.dy - membershipCost.dy).abs(), lessThan(8));
        expect(
          badge.dx,
          greaterThan(tester.getTopRight(find.text(r'$0.00')).dx),
        );
      }
      expect(find.text('Doctor embajador'), findsOneWidget);
      expect(find.text(r'$650.00'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
