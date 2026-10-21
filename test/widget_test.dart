import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chequea_app/features/auth/models/user_session.dart';
import 'package:chequea_app/features/auth/services/auth_service.dart';
import 'package:chequea_app/features/auth/services/session_expiration.dart';
import 'package:chequea_app/core/config/app_config.dart';
import 'package:chequea_app/features/home/pages/sent_messages_page.dart';
import 'package:chequea_app/features/home/services/referred_appointments_service.dart';

void main() {
  test('Panamá es el único país habilitado', () {
    expect(AppConfig.countries, [AppConfig.panama]);
    expect(AppConfig.isSupportedCountry('Panamá'), isTrue);
    expect(AppConfig.isSupportedCountry('Guatemala'), isFalse);
  });

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

  test('detecta los códigos de sesión inválida de la API', () {
    expect(
      isSessionExpiredResponse(
        http.Response('{"errorcode":"general_apptoken_exception"}', 400),
      ),
      isTrue,
    );
    expect(
      isSessionExpiredResponse(
        http.Response('{"errorcode":"access_token_invalid"}', 400),
      ),
      isTrue,
    );
    expect(
      isSessionExpiredResponse(
        http.Response('{"errorcode":"invalid_apikey"}', 401),
      ),
      isTrue,
    );
  });

  test('descarta la sesión si falla la renovación del access token', () async {
    final client = _FakeHttpClient(http.Response('', 400));
    final result = await AuthService(client: client, apiKey: 'test-key')
        .refreshSession(
          const UserSession(
            username: 'maria',
            country: 'PanamÃ¡',
            isChequeandomeAgent: false,
            refreshToken: 'invalid-refresh-token',
            accessToken: 'access',
          ),
        );

    expect(result.invalid, isTrue);
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

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this.response);

  final http.Response response;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(
        Stream.value(response.bodyBytes),
        response.statusCode,
        headers: response.headers,
      );
}
