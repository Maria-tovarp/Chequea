import 'package:chequea_app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra el mismo splash al iniciar la app', (tester) async {
    await tester.pumpWidget(const ChequeaApp(showInitialSplash: true));
    expect(find.byKey(const ValueKey('initial-splash')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.byKey(const ValueKey('initial-splash')), findsNothing);
  });
}
