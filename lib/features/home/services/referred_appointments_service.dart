import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../auth/models/user_session.dart';

class ReferredAppointmentsService {
  const ReferredAppointmentsService({http.Client? client}) : _client = client;
  final http.Client? _client;

  Future<ReferredAppointmentsResult> fetch({
    required UserSession session,
    required int page,
    String? status,
    String? attendance,
  }) async {
    final config = AppConfig.forCountry(session.country);
    final query = <String, String>{
      'page': '$page',
      'order': 'creation_date__desc',
    };
    if (status?.isNotEmpty ?? false) {
      query['appointment_status'] = status!;
    }
    if (attendance?.isNotEmpty ?? false) {
      query['appointment_attendance_status'] = attendance!;
    }
    final client = _client ?? http.Client();
    try {
      final uri = Uri.parse(
        '${Uri.parse(config.loginUrl).origin}/api/chequea-api/v1/referred_appointments',
      ).replace(queryParameters: query);
      final response = await client
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'x-api-key': config.apiKeyFor(session.country),
              'Authorization': 'Bearer ${session.accessToken}',
            },
          )
          .timeout(const Duration(seconds: 60));
      final payload = jsonDecode(response.body);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          payload is! Map) {
        debugPrint(
          'ChequeaApi: referred_appointments page=$page failed '
          'status=${response.statusCode} body=${response.body}',
        );
        throw const ReferredAppointmentsException();
      }
      final map = Map<String, dynamic>.from(payload);
      final results = map['results'];
      return ReferredAppointmentsResult(
        total: _int(map['total']),
        page: _int(map['page_number'], fallback: page),
        perPage: _int(map['total_per_page'], fallback: 50),
        currencySymbol: _text(map['currency_symbol'], fallback: r'$'),
        appointments: results is List
            ? results
                  .whereType<Map>()
                  .map(ReferralAppointment.fromJson)
                  .toList()
            : const [],
      );
    } on ReferredAppointmentsException {
      rethrow;
    } on Exception catch (error, stackTrace) {
      debugPrint(
        'ChequeaApi: referred_appointments page=$page parse/network error: '
        '$error\n$stackTrace',
      );
      throw const ReferredAppointmentsException();
    } finally {
      if (_client == null) client.close();
    }
  }
}

class ReferredAppointmentsException implements Exception {
  const ReferredAppointmentsException();
}

class ReferredAppointmentsResult {
  const ReferredAppointmentsResult({
    required this.total,
    required this.page,
    required this.perPage,
    required this.currencySymbol,
    required this.appointments,
  });
  final int total, page, perPage;
  final String currencySymbol;
  final List<ReferralAppointment> appointments;
  bool get hasNext => page * perPage < total;
  factory ReferredAppointmentsResult.fromJson(Map<String, dynamic> json) {
    final raw = json['appointments'];
    return ReferredAppointmentsResult(
      total: _int(json['total']),
      page: _int(json['page'], fallback: 1),
      perPage: _int(json['perPage'], fallback: 50),
      currencySymbol: _text(json['currencySymbol'], fallback: r'$'),
      appointments: raw is List
          ? raw.whereType<Map>().map(ReferralAppointment.fromJson).toList()
          : const [],
    );
  }
  Map<String, dynamic> toJson() => {
    'total': total,
    'page': page,
    'perPage': perPage,
    'currencySymbol': currencySymbol,
    'appointments': appointments.map((item) => item.toJson()).toList(),
  };
}

class ReferralAppointment {
  const ReferralAppointment({
    required this.id,
    required this.patientName,
    required this.clinic,
    required this.location,
    required this.creationDate,
    required this.creationTime,
    required this.appointmentDate,
    required this.appointmentTime,
    required this.status,
    required this.attendance,
    required this.finalPrice,
    required this.services,
  });
  factory ReferralAppointment.fromJson(Map value) {
    final map = Map<String, dynamic>.from(value);
    final clinicMap = _map(map['clinic']);
    final locationMap = _map(
      clinicMap['location'] ?? clinicMap['address'] ?? map['location'],
    );
    final patient = [
      _text(map['patient_firstname']),
      _text(map['patient_lastname']),
    ].where((item) => item.isNotEmpty).join(' ');
    final rawServices =
        map['services'] ?? map['items'] ?? map['appointment_services'];
    return ReferralAppointment(
      id: _text(map['id']),
      patientName: patient,
      clinic: _text(clinicMap['title'] ?? clinicMap['name']),
      location: _locationBreadcrumb(
        locationMap,
        addressAlias: _text(
          clinicMap['address_alias'] ??
              locationMap['address_alias'] ??
              map['address_alias'],
        ),
      ),
      creationDate: _text(map['creation_date'] ?? map['created']),
      creationTime: _timeFrom(
        map['creation_time'] ?? map['created_time'],
        map['creation_time_hour'],
        map['creation_time_minute'],
      ),
      appointmentDate: _text(map['appointment_date']),
      appointmentTime: _timeFrom(
        map['appointment_time'],
        map['appointment_time_hour'],
        map['appointment_time_minute'],
      ),
      status: _text(map['appointment_status'], fallback: 'pending'),
      attendance: _text(
        map['appointment_attendance_status'],
        fallback: 'pending',
      ),
      finalPrice: _number(map['total_final_price'] ?? map['total_price']),
      services: rawServices is List
          ? rawServices.whereType<Map>().map(ReferralService.fromJson).toList()
          : const [],
    );
  }
  final String id,
      patientName,
      clinic,
      location,
      creationDate,
      creationTime,
      appointmentDate,
      appointmentTime,
      status,
      attendance;
  final num? finalPrice;
  final List<ReferralService> services;
  Map<String, dynamic> toJson() => {
    'id': id,
    'patient_firstname': patientName,
    'clinic': {
      'title': clinic,
      'location': {'breadcrumb': location},
    },
    'creation_date': creationDate,
    'creation_time': creationTime,
    'appointment_date': appointmentDate,
    'appointment_time': appointmentTime,
    'appointment_status': status,
    'appointment_attendance_status': attendance,
    'total_final_price': finalPrice,
    'services': services.map((service) => service.toJson()).toList(),
  };
}

class ReferralService {
  const ReferralService({required this.name, this.price});
  factory ReferralService.fromJson(Map value) {
    final map = Map<String, dynamic>.from(value);
    final service = _map(map['service']);
    return ReferralService(
      name: _text(
        map['title'] ??
            map['name'] ??
            map['service_name'] ??
            service['title'] ??
            service['name'],
        fallback: 'Servicio',
      ),
      price: _number(map['final_price'] ?? map['price'] ?? map['total_price']),
    );
  }
  final String name;
  final num? price;
  Map<String, dynamic> toJson() => {'title': name, 'final_price': price};
}

Map _map(Object? value) => value is Map ? value : const {};
String _text(Object? value, {String fallback = ''}) =>
    value?.toString().trim().isNotEmpty == true
    ? value.toString().trim()
    : fallback;
int _int(Object? value, {int fallback = 0}) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? fallback;
num? _number(Object? value) => value is num ? value : num.tryParse('$value');

String _timeFrom(Object? raw, Object? hour, Object? minute) {
  final rawValue = raw?.toString().trim() ?? '';
  final rawMatch = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(rawValue);
  final parsedHour = rawMatch == null
      ? int.tryParse('$hour')
      : int.tryParse(rawMatch.group(1)!);
  final parsedMinute = rawMatch == null
      ? int.tryParse('$minute')
      : int.tryParse(rawMatch.group(2)!);
  if (parsedHour == null) return '';
  final period = parsedHour >= 12 ? 'p.m.' : 'a.m.';
  final displayHour = parsedHour % 12 == 0 ? 12 : parsedHour % 12;
  return '$displayHour:${(parsedMinute ?? 0).toString().padLeft(2, '0')} $period';
}

String _locationBreadcrumb(Map location, {String addressAlias = ''}) {
  final saved = _text(location['breadcrumb'] ?? location['full_path']);
  if (saved.isNotEmpty) return _readableLocation(saved);
  final parts = <String>[];
  void add(Object? item) {
    if (item is List) {
      for (final child in item) {
        add(child);
      }
      return;
    }
    if (item is! Map) return;
    add(item['parents'] ?? item['ancestors'] ?? item['path']);
    for (final key in [
      'country',
      'province',
      'state',
      'city',
      'district',
      'sector',
    ]) {
      final value = item[key];
      if (value is Map || value is List) add(value);
      final name = value is Map
          ? _text(value['name'] ?? value['title'])
          : _text(value);
      if (name.isNotEmpty && !parts.contains(name)) parts.add(name);
    }
    final name = _text(item['name'] ?? item['title'] ?? item['location_name']);
    if (name.isNotEmpty && !parts.contains(name)) parts.add(name);
    add(item['parent']);
  }

  add(location);
  final alias = addressAlias.isNotEmpty
      ? addressAlias
      : _text(location['address_alias']);
  if (alias.isNotEmpty) parts.add('($alias)');
  return _readableLocation(parts.join(' / '));
}

String _readableLocation(String value) {
  const accents = {
    'panama': 'Panamá',
    'espana': 'España',
    'via': 'Vía',
    'colon': 'Colón',
    'chitre': 'Chitré',
    'david': 'David',
  };
  return value
      .split('/')
      .map((segment) {
        final words = segment
            .trim()
            .replaceAll(RegExp(r'[-_]'), ' ')
            .split(' ');
        return words
            .where((word) => word.isNotEmpty)
            .map((word) {
              final normalized = word.toLowerCase();
              final accented = accents[normalized];
              if (accented != null) return accented;
              return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
            })
            .join(' ');
      })
      .where((segment) => segment.isNotEmpty)
      .join(' / ');
}

class ReferredAppointmentsCache {
  const ReferredAppointmentsCache._();
  static String _key({
    required UserSession session,
    required int page,
    String? status,
    String? attendance,
  }) =>
      'referred_appointments.${session.country}.${session.username}.$page.${status ?? ''}.${attendance ?? ''}';
  static Future<ReferredAppointmentsResult?> load({
    required UserSession session,
    required int page,
    String? status,
    String? attendance,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(
      _key(
        session: session,
        page: page,
        status: status,
        attendance: attendance,
      ),
    );
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      return value is Map<String, dynamic>
          ? ReferredAppointmentsResult.fromJson(value)
          : null;
    } on FormatException {
      return null;
    }
  }

  static Future<void> save({
    required UserSession session,
    required int page,
    String? status,
    String? attendance,
    required ReferredAppointmentsResult result,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key(
        session: session,
        page: page,
        status: status,
        attendance: attendance,
      ),
      jsonEncode(result.toJson()),
    );
  }
}
