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
    this.restoring = false,
  });

  const AuthState.signedOut() : this(AuthStatus.signedOut);

  final AuthStatus status;
  final String? userId;
  final String? phone;

  /// Màn hình cần mở ngay sau khi vừa đăng ký/đăng nhập (OB-6). null khi mở
  /// lại app với phiên sẵn có (NAV-1).
  final String? landing;

  /// Server báo tài khoản đã thiết lập xong lúc đăng nhập (`/v1/me`): không
  /// đưa vào thiết lập lại dù dữ liệu chưa kịp về máy.
  final bool serverSetupCompleted;

  /// Đang khôi phục dữ liệu về máy (S-07, 05 §6.6.5): chưa vào app khi dữ
  /// liệu chưa đủ.
  final bool restoring;
}

/// Đường dẫn S-07.
const restorePath = '/restore';

/// Phiên đọc từ Keychain lúc khởi động (override trong `main.dart`).
final initialSessionProvider = Provider<StoredSession?>((ref) => null);

/// Lúc khởi động: có phiên nhưng trên máy chưa có hồ sơ (cài lại app, tắt app
/// giữa lúc khôi phục) → khôi phục trước khi vào app (override trong
/// `main.dart`).
final initialRestoreProvider = Provider<bool>((ref) => false);

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
    final signedIn = session.refreshToken != null;
    return AuthState(
      signedIn ? AuthStatus.signedIn : AuthStatus.expired,
      userId: session.userId,
      phone: session.phone,
      restoring: signedIn && ref.watch(initialRestoreProvider),
    );
  }

  /// S-01a. Thành công → Bước 1/5 (S-02).
  Future<MeResponse> register({
    required String displayName,
    required String phone,
    required String password,
  }) async {
    final previous = state.userId;
    final me = await ref
        .read(authRepositoryProvider)
        .register(
          RegisterRequest(
            displayName: displayName,
            phone: phone,
            password: password,
          ),
        );
    await _forgetOtherAccount(previous, me.userId);
    await _signedIn(me, landing: SetupState.notStarted.path);
    return me;
  }

  /// S-01b. Thành công → theo OB-6: thiết lập tiếp đúng bước hoặc vào app.
  Future<MeResponse> login({
    required String phone,
    required String password,
  }) async {
    final previous = state.userId;
    final me = await ref
        .read(authRepositoryProvider)
        .login(LoginRequest(phone: phone, password: password));
    await _forgetOtherAccount(previous, me.userId);
    if (me.onboardingState == OnboardingState.completed) {
      // Cùng tài khoản, dữ liệu còn trên máy (phiên hết hạn, TA-10): vào app,
      // đồng bộ tiếp. Máy mới hoặc vừa đổi tài khoản: khôi phục (S-07, J-06).
      final local = await ref.read(profileRepositoryProvider).get();
      final hasData = local?.isOnboardingCompleted ?? false;
      await _signedIn(
        me,
        landing: hasData ? '/today' : restorePath,
        restoring: !hasData,
      );
      return me;
    }
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
        OnboardingState.completed => '/today',
      },
    );
    return me;
  }

  /// S-07 xong (VS-14): vào Hôm nay, hoặc bước thiết lập còn dở.
  void restored(SetupState setup) {
    state = AuthState(
      AuthStatus.signedIn,
      userId: state.userId,
      phone: state.phone,
      landing: setup.isCompleted ? '/today' : setup.path,
      serverSetupCompleted: setup.isCompleted,
    );
  }

  /// 05 §6.6.6: đăng nhập tài khoản khác trên máy này → xóa dữ liệu của tài
  /// khoản cũ trước khi khôi phục.
  Future<void> _forgetOtherAccount(String? previous, String userId) async {
    if (previous == null || previous == userId) return;
    ref.read(syncEngineProvider).stop();
    await ref.read(databaseProvider).wipe();
  }

  Future<void> _signedIn(
    MeResponse me, {
    required String landing,
    bool restoring = false,
  }) async {
    // Có tên ngay cho lời chào ở Hôm nay, không chờ lần đồng bộ đầu (UR-14).
    await ref.read(accountRepositoryProvider).put(me.displayName);
    state = AuthState(
      AuthStatus.signedIn,
      userId: me.userId,
      phone: me.phone,
      landing: landing,
      serverSetupCompleted: me.onboardingState == OnboardingState.completed,
      restoring: restoring,
    );
  }
}
