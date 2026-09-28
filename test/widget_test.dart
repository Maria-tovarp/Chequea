import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:chequea_app/features/auth/services/auth_service.dart';

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
}
