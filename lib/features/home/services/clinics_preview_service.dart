import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/models/user_session.dart';

class ClinicsPreviewService {
  const ClinicsPreviewService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Future<ClinicsPreview> fetch({
    required UserSession session,
    required List<int> serviceIds,
  }) async {
    if (serviceIds.isEmpty) return const ClinicsPreview(totalClinics: 0);
    final config = AppConfig.forCountry(session.country);
    final apiKey = config.apiKeyFor(session.country);
    final client = _client ?? http.Client();
    try {
      final query = serviceIds
          .map((id) => 'service_ids%5B%5D=${Uri.encodeQueryComponent('$id')}')
          .join('&');
      final response = await client.get(
        Uri.parse(
          '${Uri.parse(config.loginUrl).origin}/api/chequea-api/v1/services/clinics_preview?$query',
        ),
        headers: {
          'Accept': 'application/json',
          'x-api-key': apiKey,
          'Authorization': 'Bearer ${session.accessToken}',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const FormatException();
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) throw const FormatException();
      return ClinicsPreview(
        totalClinics: (payload['total_clinics'] as num?)?.toInt() ?? 0,
        clinicsListUrl: payload['clinics_list_url']?.toString(),
      );
    } on Exception {
      return const ClinicsPreview(totalClinics: 0);
    } finally {
      if (_client == null) client.close();
    }
  }
}

class ClinicsPreview {
  const ClinicsPreview({required this.totalClinics, this.clinicsListUrl});

  final int totalClinics;
  final String? clinicsListUrl;
}
