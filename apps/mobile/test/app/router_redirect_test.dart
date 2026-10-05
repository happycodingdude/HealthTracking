import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/router.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';

void main() {
  const out = AuthState.signedOut();
  const expired = AuthState(
    AuthStatus.expired,
    userId: 'u1',
    phone: '0912345678',
  );
  const reopened = AuthState(AuthStatus.signedIn, userId: 'u1');
  const registered = AuthState(
    AuthStatus.signedIn,
    userId: 'u1',
    landing: '/onboarding',
  );

  test(
    'VS01-T10: chưa đăng nhập → S-01; được ở trong luồng S-01/S-01a/S-01b',
    () {
      expect(authRedirect(out, '/today'), '/welcome');
      expect(authRedirect(out, '/me'), '/welcome');
      expect(authRedirect(out, '/onboarding'), '/welcome');
      expect(authRedirect(out, '/welcome'), isNull);
      expect(authRedirect(out, '/welcome/register'), isNull);
      expect(authRedirect(out, '/welcome/login'), isNull);
    },
  );

  test('VS01-T10: đăng ký xong → S-02 (Bước 1/5)', () {
    expect(authRedirect(registered, '/welcome/register'), '/onboarding');
    expect(authRedirect(registered, '/onboarding'), isNull);
  });

  test(
    'NAV-1, UA-23: mở lại app khi đã đăng nhập → vào thẳng Hôm nay, không qua S-01',
    () {
      expect(authRedirect(reopened, '/today'), isNull);
      expect(authRedirect(reopened, '/welcome'), '/today');
    },
  );

  test('TA-10: phiên hết hạn → S-01b', () {
    expect(authRedirect(expired, '/today'), '/welcome/login');
    expect(authRedirect(expired, '/welcome/login'), isNull);
  });
}
