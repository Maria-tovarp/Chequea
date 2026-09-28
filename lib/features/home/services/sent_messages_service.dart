import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../auth/models/user_session.dart';

class SentMessagesService {
  const SentMessagesService({http.Client? client}) : _client = client;
  final http.Client? _client;

  Future<SentMessagesResult> fetch({
    required UserSession session,
    required int page,
    DateTime? startDate,
    DateTime? endDate,
    String? cellphone,
  }) async {
    final query = <String, String>{'page': '$page'};
    if (startDate != null) query['date_created__start'] = _date(startDate);
    if (endDate != null) query['date_created__end'] = _date(endDate);
    final normalizedCellphone = cellphone?.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalizedCellphone != null && normalizedCellphone.isNotEmpty) {
      query['patient_cellphone_number'] = normalizedCellphone;
    }
    final result = await _request(session: session, query: query);

    // La API documenta el filtro por celular. Este respaldo permite visualizar
    // los mensajes antiguos si fueron guardados con un formato distinto (por
    // ejemplo, con o sin prefijo internacional) en el servidor.
    if (normalizedCellphone == null ||
        normalizedCellphone.isEmpty ||
        result.total > 0) {
      return result;
    }

    return _findByNormalizedCellphone(
      session: session,
      cellphone: normalizedCellphone,
      requestedPage: page,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<SentMessagesResult> _findByNormalizedCellphone({
    required UserSession session,
    required String cellphone,
    required int requestedPage,
    required DateTime? startDate,
    required DateTime? endDate,
  }) async {
    final messages = <SentMessage>[];
    var page = 1;
    SentMessagesResult current;
    do {
      final query = <String, String>{'page': '$page'};
      if (startDate != null) query['date_created__start'] = _date(startDate);
      if (endDate != null) query['date_created__end'] = _date(endDate);
      current = await _request(session: session, query: query);
      messages.addAll(
        current.messages.where(
          (message) =>
              message.cellphone.replaceAll(RegExp(r'[^0-9]'), '') == cellphone,
        ),
      );
      page++;
    } while (current.hasNext);

    const perPage = 50;
    final from = (requestedPage - 1) * perPage;
    final visible = from >= messages.length
        ? const <SentMessage>[]
        : messages.skip(from).take(perPage).toList();
    return SentMessagesResult(
      total: messages.length,
      page: requestedPage,
      perPage: perPage,
      messages: visible,
    );
  }

  Future<SentMessagesResult> _request({
    required UserSession session,
    required Map<String, String> query,
  }) async {
    final config = AppConfig.forCountry(session.country);
    final client = _client ?? http.Client();
    try {
      final response = await client.get(
        Uri.parse(
          '${Uri.parse(config.loginUrl).origin}/api/chequea-api/v1/messages/history',
        ).replace(queryParameters: query),
        headers: {
          'Accept': 'application/json',
          'x-api-key': config.apiKeyFor(session.country),
          'Authorization': 'Bearer ${session.accessToken}',
        },
      );
      final payload = jsonDecode(response.body);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          payload is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final results = payload['results'] is List
          ? payload['results'] as List
          : const [];
      return SentMessagesResult(
        total: (payload['total'] as num?)?.toInt() ?? 0,
        page:
            (payload['page_number'] as num?)?.toInt() ??
            int.tryParse(query['page'] ?? '') ??
            1,
        perPage: (payload['total_per_page'] as num?)?.toInt() ?? 50,
        messages: results.whereType<Map>().map(SentMessage.fromJson).toList(),
      );
    } on Exception {
      throw const SentMessagesException();
    } finally {
      if (_client == null) client.close();
    }
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class SentMessagesException implements Exception {
  const SentMessagesException();
}

class SentMessagesResult {
  const SentMessagesResult({
    required this.total,
    required this.page,
    required this.perPage,
    required this.messages,
  });
  final int total;
  final int page;
  final int perPage;
  final List<SentMessage> messages;
  bool get hasNext => page * perPage < total;

  factory SentMessagesResult.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    return SentMessagesResult(
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      perPage: (json['perPage'] as num?)?.toInt() ?? 50,
      messages: rawMessages is List
          ? rawMessages.whereType<Map>().map(SentMessage.fromJson).toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'total': total,
    'page': page,
    'perPage': perPage,
    'messages': messages.map((message) => message.toJson()).toList(),
  };
}

class SentMessage {
  const SentMessage({
    required this.referrerName,
    required this.referrerUsername,
    required this.cellphone,
    required this.services,
    this.plaintextServices,
    this.createdDate,
    this.createdTime,
  });

  factory SentMessage.fromJson(Map value) {
    final referrer = value['referrer'] is Map
        ? value['referrer'] as Map
        : const {};
    final serviceData = value['services'] is Map
        ? value['services'] as Map
        : const {};
    final items = serviceData['items'] is List
        ? serviceData['items'] as List
        : const [];
    return SentMessage(
      referrerName: referrer['fullname']?.toString() ?? '',
      referrerUsername: referrer['name']?.toString() ?? '',
      cellphone: value['patient_cellphone_number']?.toString() ?? '',
      services: items
          .whereType<Map>()
          .map((item) => item['title']?.toString() ?? '')
          .where((title) => title.isNotEmpty)
          .toList(),
      plaintextServices: value['plaintext_services']?.toString(),
      createdDate: value['date_created__date']?.toString(),
      createdTime: value['date_created__time']?.toString(),
    );
  }

  final String referrerName;
  final String referrerUsername;
  final String cellphone;
  final List<String> services;
  final String? plaintextServices;
  final String? createdDate;
  final String? createdTime;

  Map<String, dynamic> toJson() => {
    'referrer': {'fullname': referrerName, 'name': referrerUsername},
    'patient_cellphone_number': cellphone,
    'services': {
      'items': services.map((title) => {'title': title}).toList(),
    },
    'plaintext_services': plaintextServices,
    'date_created__date': createdDate,
    'date_created__time': createdTime,
  };
}

class SentMessagesCache {
  const SentMessagesCache._();

  static String _key({
    required UserSession session,
    required int page,
    DateTime? startDate,
    DateTime? endDate,
    String? cellphone,
  }) {
    final phone = cellphone?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    String date(DateTime? value) => value == null
        ? ''
        : '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    return 'sent_messages.${session.country}.${session.username}.$page.${date(startDate)}.${date(endDate)}.$phone';
  }

  static Future<SentMessagesResult?> load({
    required UserSession session,
    required int page,
    DateTime? startDate,
    DateTime? endDate,
    String? cellphone,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(
      _key(
        session: session,
        page: page,
        startDate: startDate,
        endDate: endDate,
        cellphone: cellphone,
      ),
    );
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      return value is Map<String, dynamic>
          ? SentMessagesResult.fromJson(value)
          : null;
    } on FormatException {
      return null;
    }
  }

  static Future<void> save({
    required UserSession session,
    required int page,
    DateTime? startDate,
    DateTime? endDate,
    String? cellphone,
    required SentMessagesResult result,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key(
        session: session,
        page: page,
        startDate: startDate,
        endDate: endDate,
        cellphone: cellphone,
      ),
      jsonEncode(result.toJson()),
    );
  }
}
