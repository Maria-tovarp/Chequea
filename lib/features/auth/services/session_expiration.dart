import 'dart:convert';

import 'package:http/http.dart' as http;

bool isSessionExpiredResponse(http.Response response) {
  final payload = _payload(response.body);
  final errorCode = payload?['errorcode']?.toString();
  return errorCode == 'invalid_apikey' ||
      errorCode == 'access_token_invalid' ||
      errorCode == 'general_apptoken_exception';
}

Map? _payload(String value) {
  try {
    final decoded = jsonDecode(value);
    return decoded is Map ? decoded : null;
  } on FormatException {
    return null;
  }
}
