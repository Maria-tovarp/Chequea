import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chequea_app/features/auth/models/user_session.dart';
import 'package:chequea_app/features/auth/services/auth_service.dart';
import 'package:chequea_app/features/home/pages/sent_messages_page.dart';
import 'package:chequea_app/features/home/services/referred_appointments_service.dart';

void main() {
  test('acepta una respuesta de refresh token de la API', () {
    final response = http.Response(
      '{"refresh_token":"token-de-prueba","username":"maria-tovar"}',
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

    expect(hasValidCredentialsResponse(response), isTrue);
  });

  test('detecta una cuenta que no es referente en la respuesta de la API', () {
    final response = http.Response(
      '{"errorcode":"cheq__auth_only_referrer_accounts_allowed"}',
      403,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

    expect(brandingLockMessage(response), contains('referentes'));
  });

  test(
    'detecta si la respuesta del endpoint marca un agente de Chequeándome',
    () {
      final response = http.Response(
        '{"is_chq_agent":true}',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

      expect(isChequeandomeAgentResponse(response), isTrue);
    },
  );

  test('obtiene el nombre de un CHEQUEA Branding autenticado', () {
    expect(
      brandingNameFromPayload({
        'chequea_branding': {'title': 'MiniMed'},
      }),
      'MiniMed',
    );
  });

  test('admite el nombre de Branding directo de la API', () {
    expect(
      brandingNameFromPayload({'chequea_branding_title': 'MiniMed'}),
      'MiniMed',
    );
  });

  test('lee una referencia con paciente y servicios anidados', () {
    final appointment = ReferralAppointment.fromJson({
      'id': 16199,
      'patient': {'first_name': 'Kely', 'last_name': 'Daly'},
      'clinic': {
        'name': 'Centro Medico San Luis',
        'address_alias': 'Via Espana',
        'location': {'breadcrumb': 'Panama / Intermedio'},
      },
      'creation_date': '2024-10-17',
      'appointment_date': '2024-10-18',
      'appointment_status': 'ok',
      'appointment_attendance_status': 'pending',
      'final_price': 5486,
      'services': {
        'items': [
          {'title': 'T3', 'final_price': 15},
        ],
      },
    });

    expect(appointment.patientName, 'Kely Daly');
    expect(appointment.location, contains('(Via Espana)'));
    expect(appointment.finalPrice, 5486);
    expect(appointment.services.single.name, 'T3');
  });

  testWidgets('renderiza Mis enviados mientras carga', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(
        home: SentMessagesPage(
          session: UserSession(
            username: 'maria',
            country: 'Panamá',
            isChequeandomeAgent: false,
            refreshToken: 'refresh',
            accessToken: 'access',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
