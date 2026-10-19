import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chequea_app/features/home/widgets/app_notice_dialog.dart';

void main() {
  for (final notice in {
    'Regalos': 'En esta sección podrás recibir regalos por utilizar CHEQUEA.',
    'Notificaciones': 'Esta función estará disponible pronto.',
  }.entries) {
    testWidgets('${notice.key} abre y cierra el aviso compartido', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(appBar: null, body: HeaderNoticeActions()),
        ),
      );
      await tester.tap(find.byTooltip(notice.key));
      await tester.pumpAndSettle();
      expect(find.text('Próximamente'), findsOneWidget);
      expect(find.text(notice.value), findsOneWidget);
      await tester.tap(find.text('ENTENDIDO'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });
  }
}
