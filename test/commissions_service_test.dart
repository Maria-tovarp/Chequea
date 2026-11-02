import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:chequea_app/features/auth/models/user_session.dart';
import 'package:chequea_app/features/home/services/commissions_service.dart';

void main() {
  test('obtiene y convierte las comisiones y pagos recientes', () async {
    final service = CommissionsService(client: _Client());
    final result = await service.fetch(
      const UserSession(
        username: 'maria',
        country: 'Panamá',
        isChequeandomeAgent: false,
        refreshToken: 'refresh',
        accessToken: 'access',
      ),
    );

    expect(result.sentChequeas.totalSent, 3);
    expect(result.sentChequeas.amountPerSent, 0.5);
    expect(result.refAttendedAppointments.percentage, 5);
    expect(result.grandTotal, 56);
    expect(result.payments, hasLength(2));
    expect(result.payments.first.year, 2026);
    expect(result.payments.first.month, 9);
    expect(result.payments.first.total, 10.97);
  });
}

class _Client extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = request.url.path.endsWith('/commissions/current')
        ? '''{"sent_chequeas":{"total_sent":3,"comm_amount_per_sent":0.5,"total_commission":1.5},"ref_attended_appts":{"total_price":1027.99,"pct_per_appt":5,"total_commission":51.4},"ref_invs_attended_appts":{"total_price":310,"pct_per_appt":1,"total_commission":3.1},"grand_total_commission":56}'''
        : '''[{"year":2026,"month":9,"total_payment":10.97},{"year":2026,"month":8,"total_payment":0.5}]''';
    return http.StreamedResponse(Stream.value(body.codeUnits), 200);
  }
}
