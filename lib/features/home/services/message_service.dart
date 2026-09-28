import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/models/user_session.dart';

class MessageService {
  const MessageService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Future<MessageSendResult> send({
    required UserSession session,
    required String mode,
    required String patientCellphoneNumber,
    List<int> serviceIds = const [],
    String? plaintextServices,
    String? filePath,
  }) async {
    final config = AppConfig.forCountry(session.country);
    final apiKey = config.apiKeyFor(session.country);
    if (apiKey.isEmpty) {
      return const MessageSendResult.failure(
        'Falta configurar la clave de acceso de la aplicación.',
      );
    }
    final client = _client ?? http.Client();
    try {
      final request =
          http.MultipartRequest(
              'POST',
              Uri.parse(
                '${Uri.parse(config.loginUrl).origin}/api/chequea-api/v1/messages/mode/$mode',
              ),
            )
            ..headers.addAll({
              'Accept': 'application/json',
              'x-api-key': apiKey,
              'Authorization': 'Bearer ${session.accessToken}',
            })
            ..fields['patient_cellphone_number'] = patientCellphoneNumber;

      for (final serviceId in serviceIds) {
        request.files.add(
          http.MultipartFile.fromString('services[]', serviceId.toString()),
        );
      }
      if (plaintextServices != null && plaintextServices.trim().isNotEmpty) {
        request.fields['plaintext_services'] = plaintextServices.trim();
      }
      if (filePath != null) {
        request.files.add(await http.MultipartFile.fromPath('file', filePath));
      }

      final response = await http.Response.fromStream(
        await client.send(request),
      );
      final payload = _payload(response.body);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          payload['success'] == true) {
        return MessageSendResult.success(
          payload['message']?.toString() ?? 'Mensaje enviado correctamente.',
        );
      }
      final validation = payload['validation_messages'];
      if (validation is Map && validation.isNotEmpty) {
        return MessageSendResult.failure(validation.values.first.toString());
      }
      return MessageSendResult.failure(
        payload['error']?.toString() ?? 'No fue posible enviar el mensaje.',
      );
    } on Exception {
      return const MessageSendResult.failure(
        'No se pudo conectar con el servicio.',
      );
    } finally {
      if (_client == null) client.close();
    }
  }
}

class MessageSendResult {
  const MessageSendResult._({required this.success, required this.message});
  const MessageSendResult.success(String message)
    : this._(success: true, message: message);
  const MessageSendResult.failure(String message)
    : this._(success: false, message: message);

  final bool success;
  final String message;
}

Map<String, dynamic> _payload(String body) {
  try {
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : const {};
  } on FormatException {
    return const {};
  }
}
