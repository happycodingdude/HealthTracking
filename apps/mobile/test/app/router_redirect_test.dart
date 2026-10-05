import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/router.dart';
import 'package:mobile/core/widgets/reference_tag.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/onboarding/application/setup_state.dart';

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
    landing: '/onboarding/1',
  );
  const done = SetupState.completed;
  const fresh = SetupState.notStarted;
  final atStep3 = SetupState.of(const Profile(onboardingStep: 3));

  String? go(AuthState a, SetupState s, String location) =>
      appRedirect(a, s, location);

  test(
    'VS01-T10: chưa đăng nhập → S-01; được ở trong luồng S-01/S-01a/S-01b',
    () {
      expect(go(out, fresh, '/today'), '/welcome');
      expect(go(out, fresh, '/me'), '/welcome');
      expect(go(out, fresh, '/onboarding/1'), '/welcome');
      expect(go(out, fresh, '/welcome'), isNull);
      expect(go(out, fresh, '/welcome/register'), isNull);
      expect(go(out, fresh, '/welcome/login'), isNull);
    },
  );

  test('VS01-T10: đăng ký xong → S-02 (Bước 1/5); OB-6: đăng nhập → đúng '
      'bước đã tính từ hồ sơ vừa lấy về', () {
    const loggedIn = AuthState(
      AuthStatus.signedIn,
      userId: 'u1',
      landing: '/onboarding/3',
    );
    expect(go(loggedIn, fresh, '/welcome/login'), '/onboarding/3');
    expect(go(registered, fresh, '/welcome/register'), '/onboarding/1');
    expect(go(registered, fresh, '/onboarding'), '/onboarding/1');
    expect(go(registered, fresh, '/onboarding/1'), isNull);
  });

  test(
    'NAV-1, UA-23: mở lại app khi đã thiết lập xong → vào thẳng Hôm nay',
    () {
      expect(go(reopened, done, '/today'), isNull);
      expect(go(reopened, done, '/welcome'), '/today');
      expect(go(reopened, done, '/onboarding/2'), '/today');
    },
  );

  test(
    'OB-3, F01-R1: thiết lập dở → mở lại đúng bước; không vào được các tab',
    () {
      expect(go(reopened, atStep3, '/today'), '/onboarding/3');
      expect(go(reopened, atStep3, '/me/account'), '/onboarding/3');
      expect(go(reopened, atStep3, '/onboarding'), '/onboarding/3');
      expect(go(reopened, atStep3, '/onboarding/9'), '/onboarding/3');
      // OB-2: quay lại bước trước.
      expect(go(reopened, atStep3, '/onboarding/2'), isNull);
    },
  );

  test('F10-R4: S-55 xem được cả khi đang thiết lập', () {
    expect(go(reopened, atStep3, aboutReferencePath), isNull);
    expect(go(reopened, done, aboutReferencePath), isNull);
  });

  test('OB-6: tài khoản đã thiết lập xong trên server → không thiết lập lại dù '
      'hồ sơ chưa về máy', () {
    const loggedIn = AuthState(
      AuthStatus.signedIn,
      userId: 'u1',
      landing: '/today',
      serverSetupCompleted: true,
    );
    expect(go(loggedIn, fresh, '/welcome/login'), '/today');
    expect(go(loggedIn, fresh, '/today'), isNull);
  });

  test('TA-10: phiên hết hạn → S-01b', () {
    expect(go(expired, done, '/today'), '/welcome/login');
    expect(go(expired, done, '/welcome/login'), isNull);
  });
}
