import 'package:chequea_app/features/auth/models/user_session.dart';
import 'package:chequea_app/features/auth/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  const session = UserSession(
    username: 'maria',
    country: 'Panamá',
    isChequeandomeAgent: false,
    refreshToken: 'refresh-token',
    accessToken: 'access-token',
  );

  test('elimina la cuenta con POST y el access token actual', () async {
    final client = _RecordingHttpClient(http.Response('{"success":true}', 200));

    final result = await AuthService(
      client: client,
      apiKey: 'test-key',
    ).deleteAccount(session);

    expect(result.deleted, isTrue);
    expect(client.request!.method, 'POST');
    expect(client.request!.url.path, '/api/chequea-api/v1/account/delete');
    expect(client.request!.headers['x-api-key'], 'test-key');
    expect(client.request!.headers['authorization'], 'Bearer access-token');
  });

  test('preserva el mensaje del servidor si no permite eliminar', () async {
    final client = _RecordingHttpClient(
      http.Response(
        '{"error":"No es posible eliminar esta cuenta por esta vía."}',
        500,
      ),
    );

    final result = await AuthService(
      client: client,
      apiKey: 'test-key',
    ).deleteAccount(session);

    expect(result.deleted, isFalse);
    expect(result.statusCode, 500);
    expect(result.error, 'No es posible eliminar esta cuenta por esta vía.');
  });
}

class _RecordingHttpClient extends http.BaseClient {
  _RecordingHttpClient(this.response);

  final http.Response response;
  http.BaseRequest? request;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest value) async {
    request = value;
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}
