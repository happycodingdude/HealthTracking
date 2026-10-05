import 'package:domain/domain.dart';
import 'package:server/src/auth/login_rate_limiter.dart';
import 'package:test/test.dart';

void main() {
  late FixedClock clock;
  late LoginRateLimiter limiter;

  setUp(() {
    clock = FixedClock(DateTime.utc(2026, 10, 7, 10));
    limiter = LoginRateLimiter(clock);
  });

  void fail(String phone, [String ip = '1.1.1.1']) =>
      limiter.recordFailure(phone: phone, ip: ip);

  test('TAC-15: 5 lần sai liên tiếp → lần thứ 6 bị chặn', () {
    for (var i = 1; i <= 5; i++) {
      expect(
        limiter.isBlocked(phone: '0912345678', ip: '1.1.1.1'),
        isFalse,
        reason: 'lần $i',
      );
      fail('0912345678');
    }
    expect(limiter.isBlocked(phone: '0912345678', ip: '1.1.1.1'), isTrue);
  });

  test('05 §6.8.4: chặn 15 phút rồi mở lại', () {
    for (var i = 0; i < 5; i++) {
      fail('0912345678');
    }
    clock.advance(const Duration(minutes: 14, seconds: 59));
    expect(
      limiter.isBlocked(phone: '0912345678', ip: '9.9.9.9'),
      isTrue,
      reason: 'chặn theo số điện thoại',
    );
    clock.advance(const Duration(seconds: 1));
    expect(limiter.isBlocked(phone: '0912345678', ip: '9.9.9.9'), isFalse);
  });

  test('05 §6.8.4: lần sai cũ hơn 15 phút không được đếm', () {
    for (var i = 0; i < 4; i++) {
      fail('0912345678');
    }
    clock.advance(const Duration(minutes: 15));
    fail('0912345678');
    expect(limiter.isBlocked(phone: '0912345678', ip: '1.1.1.1'), isFalse);
  });

  test('05 §6.8.4: chặn theo IP khi dò nhiều số điện thoại', () {
    for (var i = 0; i < 5; i++) {
      fail('090000000$i', '2.2.2.2');
    }
    expect(limiter.isBlocked(phone: '0999999999', ip: '2.2.2.2'), isTrue);
    expect(limiter.isBlocked(phone: '0999999999', ip: '3.3.3.3'), isFalse);
  });

  test('đăng nhập đúng xóa đếm sai của số điện thoại, giữ đếm theo IP', () {
    for (var i = 0; i < 4; i++) {
      fail('0912345678');
    }
    limiter.recordSuccess(phone: '0912345678');
    fail('0912345678', '4.4.4.4');
    expect(limiter.isBlocked(phone: '0912345678', ip: '5.5.5.5'), isFalse);
    fail('0911111111');
    expect(
      limiter.isBlocked(phone: '0922222222', ip: '1.1.1.1'),
      isTrue,
      reason: 'IP 1.1.1.1 đã sai 5 lần',
    );
  });

  test('sweep dọn mục đã hết hạn', () {
    fail('0912345678');
    expect(limiter.trackedKeys, 2);
    clock.advance(const Duration(minutes: 16));
    limiter.sweep();
    expect(limiter.trackedKeys, 0);
  });
}
