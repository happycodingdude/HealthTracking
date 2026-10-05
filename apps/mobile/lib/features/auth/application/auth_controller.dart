import 'dart:async';

import 'package:api_contract/api_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/auth/session_store.dart';
import '../../../data/sync/sync_providers.dart';
import '../../onboarding/application/setup_state.dart';

enum AuthStatus {
  /// Chưa đăng nhập trên máy này → S-01.
  signedOut,

  /// Có phiên (refresh token) → vào app, không phải đăng nhập lại (UA-23).
  signedIn,

  /// Phiên hết hạn (TA-10) → S-01b, dữ liệu trên máy được giữ.
  expired,
}

/// Trạng thái đăng nhập của app.
final class AuthState {
  const AuthState(
    this.status, {
    this.userId,
    this.phone,
    this.landing,
    this.serverSetupCompleted = false,
  });

  const AuthState.signedOut() : this(AuthStatus.signedOut);

  final AuthStatus status;
  final String? userId;
  final String? phone;

  /// Màn hình cần mở ngay sau khi vừa đăng ký/đăng nhập (OB-6). null khi mở
  /// lại app với phiên sẵn có (NAV-1).
  final String? landing;

  /// Server báo tài khoản đã thiết lập xong lúc đăng nhập (`/v1/me`): không
  /// đưa vào thiết lập lại dù dữ liệu chưa kịp về máy (khôi phục ở VS-14).
  final bool serverSetupCompleted;
}

/// Phiên đọc từ Keychain lúc khởi động (override trong `main.dart`).
final initialSessionProvider = Provider<StoredSession?>((ref) => null);

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Đăng ký, đăng nhập và trạng thái phiên (F-09). UI chỉ gọi các hàm này.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final sub = ref.watch(tokenManagerProvider).onExpired.listen((_) {
      state = AuthState(
        AuthStatus.expired,
        userId: state.userId,
        phone: state.phone,
      );
    });
    ref.onDispose(sub.cancel);

    final session = ref.watch(initialSessionProvider);
    if (session == null) return const AuthState.signedOut();
    return AuthState(
      session.refreshToken == null ? AuthStatus.expired : AuthStatus.signedIn,
      userId: session.userId,
      phone: session.phone,
    );
  }

  /// S-01a. Thành công → Bước 1/5 (S-02).
  Future<MeResponse> register({
    required String displayName,
    required String phone,
    required String password,
  }) async {
    final me = await ref
        .read(authRepositoryProvider)
        .register(
          RegisterRequest(
            displayName: displayName,
            phone: phone,
            password: password,
          ),
        );
    await _signedIn(me, landing: SetupState.notStarted.path);
    return me;
  }

  /// S-01b. Thành công → theo OB-6: thiết lập tiếp đúng bước hoặc vào app.
  Future<MeResponse> login({
    required String phone,
    required String password,
  }) async {
    final me = await ref
        .read(authRepositoryProvider)
        .login(LoginRequest(phone: phone, password: password));
    if (me.onboardingState != OnboardingState.notStarted) {
      // Lấy hồ sơ về máy trước để mở đúng bước, thông tin đã nhập còn nguyên
      // (OB-6). Lỗi mạng thì vào với dữ liệu đang có, đồng bộ tự chạy lại.
      await ref.read(syncEngineProvider).syncNow();
    }
    await _signedIn(
      me,
      landing: switch (me.onboardingState) {
        OnboardingState.notStarted || OnboardingState.inProgress =>
          SetupState.of(await ref.read(profileRepositoryProvider).get()).path,
        // Khôi phục dữ liệu (S-07) được thêm ở VS-14.
        OnboardingState.completed => '/today',
      },
    );
    return me;
  }

  Future<void> _signedIn(MeResponse me, {required String landing}) async {
    // Có tên ngay cho lời chào ở Hôm nay, không chờ lần đồng bộ đầu (UR-14).
    await ref.read(accountRepositoryProvider).put(me.displayName);
    state = AuthState(
      AuthStatus.signedIn,
      userId: me.userId,
      phone: me.phone,
      landing: landing,
      serverSetupCompleted: me.onboardingState == OnboardingState.completed,
    );
  }
}
