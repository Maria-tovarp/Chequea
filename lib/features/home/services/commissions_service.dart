import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/models/user_session.dart';
import '../../auth/services/session_expiration.dart';

class CommissionsService {
  const CommissionsService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Future<CommissionsData> fetch(UserSession session) async {
    final config = AppConfig.forCountry(session.country);
    final client = _client ?? http.Client();
    try {
      final headers = {
        'Accept': 'application/json',
        'x-api-key': config.apiKeyFor(session.country),
        'Authorization': 'Bearer ${session.accessToken}',
      };
      final configuredUri = Uri.tryParse(config.loginUrl);
      // A placeholder origin keeps injected HTTP clients usable in tests when
      // no --dart-define base URL has been supplied.
      final origin = configuredUri != null && configuredUri.hasScheme
          ? configuredUri.origin
          : 'https://chequea.invalid';
      final responses = await Future.wait([
        client
            .get(
              Uri.parse('$origin/api/chequea-api/v1/commissions/current'),
              headers: headers,
            )
            .timeout(const Duration(seconds: 30)),
        client
            .get(
              Uri.parse('$origin/api/chequea-api/v1/payments/recent'),
              headers: headers,
            )
            .timeout(const Duration(seconds: 30)),
      ]);
      if (responses.any(isSessionExpiredResponse))
        throw const CommissionsException.sessionExpired();
      final commissions = _json(responses[0].body);
      final payments = _json(responses[1].body);
      if (responses.any(
            (response) =>
                response.statusCode < 200 || response.statusCode >= 300,
          ) ||
          commissions is! Map ||
          payments is! List)
        throw const CommissionsException();
      return CommissionsData.fromJson(
        Map<String, dynamic>.from(commissions),
        payments.whereType<Map>().map(Map<String, dynamic>.from).toList(),
      );
    } on CommissionsException {
      rethrow;
    } on Exception {
      throw const CommissionsException();
    } finally {
      if (_client == null) client.close();
    }
  }
}

class CommissionsException implements Exception {
  const CommissionsException({this.sessionExpired = false});
  const CommissionsException.sessionExpired() : sessionExpired = true;
  final bool sessionExpired;
}

class CommissionsData {
  const CommissionsData({
    required this.sentChequeas,
    required this.refAttendedAppointments,
    required this.invitedReferrersAttendedAppointments,
    required this.grandTotal,
    required this.payments,
  });
  factory CommissionsData.fromJson(
    Map<String, dynamic> commissions,
    List<Map<String, dynamic>> payments,
  ) => CommissionsData(
    sentChequeas: SentChequeasCommission.fromJson(
      _map(commissions['sent_chequeas']),
    ),
    refAttendedAppointments: AppointmentCommission.fromJson(
      _map(commissions['ref_attended_appts']),
    ),
    invitedReferrersAttendedAppointments: AppointmentCommission.fromJson(
      _map(commissions['ref_invs_attended_appts']),
    ),
    grandTotal: _number(commissions['grand_total_commission']),
    payments: payments.map(RecentPayment.fromJson).toList(),
  );
  final SentChequeasCommission sentChequeas;
  final AppointmentCommission refAttendedAppointments,
      invitedReferrersAttendedAppointments;
  final num grandTotal;
  final List<RecentPayment> payments;
}

class SentChequeasCommission {
  const SentChequeasCommission({
    required this.totalSent,
    required this.amountPerSent,
    required this.total,
  });
  factory SentChequeasCommission.fromJson(Map<String, dynamic> json) =>
      SentChequeasCommission(
        totalSent: _int(json['total_sent']),
        amountPerSent: _number(json['comm_amount_per_sent']),
        total: _number(json['total_commission']),
      );
  final int totalSent;
  final num amountPerSent, total;
}

class AppointmentCommission {
  const AppointmentCommission({
    required this.totalPrice,
    required this.percentage,
    required this.total,
  });
  factory AppointmentCommission.fromJson(Map<String, dynamic> json) =>
      AppointmentCommission(
        totalPrice: _number(json['total_price']),
        percentage: _number(json['pct_per_appt']),
        total: _number(json['total_commission']),
      );
  final num totalPrice, percentage, total;
}

class RecentPayment {
  const RecentPayment({
    required this.year,
    required this.month,
    required this.total,
  });
  factory RecentPayment.fromJson(Map<String, dynamic> json) => RecentPayment(
    year: _int(json['year']),
    month: _int(json['month']),
    total: _number(json['total_payment']),
  );
  final int year, month;
  final num total;
}

Object? _json(String body) {
  try {
    return jsonDecode(body);
  } on FormatException {
    return null;
  }
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};
int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
num _number(Object? value) =>
    value is num ? value : num.tryParse('$value') ?? 0;
