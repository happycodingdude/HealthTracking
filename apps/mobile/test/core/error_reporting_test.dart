import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error_reporting.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  test(
    'TD-13: bỏ user, request, extra, tên máy; lọc số trong message và exception',
    () {
      final event = SentryEvent(
        user: SentryUser(id: 'u1', username: 'Minh'),
        request: SentryRequest(
          url: 'https://api.x/v1/auth/login',
          data: {'phone': '0901234567', 'password': '***REMOVED***'},
        ),
        serverName: "Minh's iPhone",
        // ignore: deprecated_member_use
        extra: {'weight': 725},
        message: SentryMessage('Sai số 0901234567 nặng 72,5 kg'),
        exceptions: [
          SentryException(type: 'StateError', value: 'calo 2.210 không hợp lệ'),
        ],
        breadcrumbs: [
          Breadcrumb.http(
            url: Uri.parse('https://api.x/v1/sync/pull?cursor=1042'),
            method: 'GET',
            statusCode: 200,
          ),
          Breadcrumb(
            message: 'phone 0901234567',
            category: 'console',
            data: {'body': '{"password":"***REMOVED***"}'},
          ),
        ],
      );

      final out = scrubEvent(event);

      expect(out.user, isNull);
      expect(out.request, isNull);
      expect(out.serverName, isNull);
      // ignore: deprecated_member_use
      expect(out.extra, isNull);
      expect(out.message!.formatted, 'Sai số <n> nặng <n> kg');
      expect(out.exceptions!.single.value, 'calo <n> không hợp lệ');
      expect(out.exceptions!.single.type, 'StateError');
      final http = out.breadcrumbs![0];
      expect(http.data!['url'], 'https://api.x/v1/sync/pull');
      expect(http.data!['method'], 'GET');
      expect(http.data!['status_code'], 200);
      final console = out.breadcrumbs![1];
      expect(console.message, 'phone <n>');
      expect(console.data, isEmpty);
      expect(out.toJson().toString(), isNot(contains('0901234567')));
      expect(out.toJson().toString(), isNot(contains('***REMOVED***')));
    },
  );

  test('giữ nguyên giờ HH:mm và chữ thường', () {
    expect(scrubText('Lúc 18:00 thứ 2'), 'Lúc 18:00 thứ 2');
  });
}
