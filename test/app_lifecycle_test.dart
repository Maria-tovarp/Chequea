import 'package:chequea_app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra el mismo splash al iniciar la app', (tester) async {
    await tester.pumpWidget(const ChequeaApp(showInitialSplash: true));
    expect(find.byKey(const ValueKey('resume-splash')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.byKey(const ValueKey('resume-splash')), findsNothing);
  });

  testWidgets('muestra el splash al volver desde segundo plano', (
    tester,
  ) async {
    await tester.pumpWidget(const ChequeaApp());
    expect(find.byKey(const ValueKey('resume-splash')), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byKey(const ValueKey('resume-splash')), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(const ValueKey('resume-splash')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.byKey(const ValueKey('resume-splash')), findsNothing);
  });
}
