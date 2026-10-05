import 'package:api_contract/api_contract.dart';
import 'package:test/test.dart';

void main() {
  test('RegisterRequest khứ hồi JSON', () {
    const r = RegisterRequest(
      displayName: 'Minh',
      phone: '0912345678',
      password: '***REMOVED***',
    );
    final back = RegisterRequest.fromJson(r.toJson());
    expect(back.toJson(), r.toJson());
    expect(r.toJson().keys, ['displayName', 'phone', 'password']);
  });

  test('LoginRequest, RefreshRequest khứ hồi JSON', () {
    const l = LoginRequest(phone: '0912345678', password: '***REMOVED***');
    expect(LoginRequest.fromJson(l.toJson()).toJson(), l.toJson());
    const f = RefreshRequest(refreshToken: '***REMOVED***');
    expect(RefreshRequest.fromJson(f.toJson()).refreshToken, '***REMOVED***');
  });

  test('TokenPair khứ hồi JSON, thời điểm UTC', () {
    final t = TokenPair(
      accessToken: '***REMOVED***',
      refreshToken: '***REMOVED***',
      accessTokenExpiresAt: DateTime.utc(2026, 10, 7, 11, 57),
    );
    expect(t.toJson()['accessTokenExpiresAt'], '2026-10-07T11:57:00.000Z');
    final back = TokenPair.fromJson(t.toJson());
    expect(back.accessTokenExpiresAt, t.accessTokenExpiresAt);
  });

  test(
    'MeResponse khứ hồi JSON; onboardingStep tùy chọn (TA-16: chỉ thêm trường)',
    () {
      const me = MeResponse(
        userId: 'u',
        phone: '0912345678',
        displayName: 'Minh',
        onboardingState: OnboardingState.notStarted,
      );
      expect(me.toJson(), {
        'userId': 'u',
        'phone': '0912345678',
        'displayName': 'Minh',
        'onboardingState': 'not_started',
      });
      final step = MeResponse.fromJson({
        ...me.toJson(),
        'onboardingState': 'in_progress',
        'onboardingStep': 3,
      });
      expect(step.onboardingState, OnboardingState.inProgress);
      expect(step.onboardingStep, 3);
    },
  );

  test(
    'thiếu trường hoặc sai kiểu → ContractFormatException có tên trường',
    () {
      expect(
        () => RegisterRequest.fromJson({
          'displayName': 'Minh',
          'phone': 912345678,
          'password': '***REMOVED***',
        }),
        throwsA(
          isA<ContractFormatException>().having(
            (e) => e.field,
            'field',
            'phone',
          ),
        ),
      );
      expect(
        () => LoginRequest.fromJson({'phone': '0912345678'}),
        throwsA(
          isA<ContractFormatException>().having(
            (e) => e.field,
            'field',
            'password',
          ),
        ),
      );
      expect(
        () => MeResponse.fromJson({
          'userId': 'u',
          'phone': 'p',
          'displayName': 'd',
          'onboardingState': 'x',
        }),
        throwsA(isA<ContractFormatException>()),
      );
    },
  );
}
