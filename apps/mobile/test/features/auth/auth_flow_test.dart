import 'package:api_contract/api_contract.dart';
import 'package:domain/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/app/theme.dart';
import 'package:mobile/core/widgets/labeled_field.dart';
import 'package:mobile/data/auth/session_store.dart';
import 'package:mobile/features/auth/presentation/login_screen.dart';
import 'package:mobile/features/auth/presentation/register_screen.dart';
import 'package:mobile/features/auth/presentation/welcome_screen.dart';

import '../../support/app_harness.dart';
import '../../support/fake_server.dart';
import '../../support/schedule_fixture.dart';

/// Refresh token server giả cấp khi đăng ký/đăng nhập.
final _refreshToken = randomTestSecret();

Map<String, Object?> _pair() => {
  'accessToken': randomTestSecret(),
  'refreshToken': _refreshToken,
  'accessTokenExpiresAt': '2099-01-01T00:00:00.000Z',
};

Map<String, Object?> _me() => {
  'userId': 'u1',
  'phone': '0912345678',
  'displayName': 'Minh',
  'onboardingState': 'not_started',
};

Map<String, Object?> _error(String code, [String? field]) => {
  'error': {'code': code, 'field': ?field},
};

void main() {
  late FakeServer server;
  late ProviderContainer container;

  setUp(() {
    server = FakeServer()
      ..on('POST', '/v1/auth/register', (_) => (201, _pair()))
      ..on('POST', '/v1/auth/login', (_) => (200, _pair()))
      ..on('GET', '/v1/me', (_) => (200, _me()));
  });

  Future<void> pumpSignedOut(
    WidgetTester tester, {
    StoredSession? session,
  }) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 1200 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: appOverrides(session: session, server: server),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const HealthApp()),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String label) =>
      find.byWidgetPredicate((w) => w is LabeledField && w.label == label);
  Finder input(String label) =>
      find.descendant(of: field(label), matching: find.byType(TextField));

  Future<void> openRegister(WidgetTester tester) async {
    await pumpSignedOut(tester);
    await tester.tap(find.widgetWithText(FilledButton, S.register));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);
  }

  Future<void> fillRegister(
    WidgetTester tester, {
    String name = 'Minh',
    String phone = '0912345678',
    String? password,
    String? confirm,
  }) async {
    final pw = password ?? randomTestPassword();
    await tester.enterText(input(S.fieldDisplayName), name);
    await tester.enterText(input(S.fieldPhone), phone);
    await tester.enterText(input(S.fieldPassword), pw);
    await tester.enterText(input(S.fieldPasswordConfirm), confirm ?? pw);
  }

  Future<void> tapRegisterButton(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, S.register));
    await tester.pumpAndSettle();
  }

  group('S-01', () {
    testWidgets(
      'chưa đăng nhập → S-01 có Đăng ký (chính), Đăng nhập, câu giá trị',
      (tester) async {
        await pumpSignedOut(tester);
        expect(find.byType(WelcomeScreen), findsOneWidget);
        expect(find.text(S.welcomeTagline), findsOneWidget);
        expect(find.text(S.welcomeFootnote), findsOneWidget);
        expect(find.widgetWithText(FilledButton, S.register), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, S.login), findsOneWidget);
      },
    );
  });

  group('S-01a', () {
    testWidgets(
      'UX-AC3: đăng ký gồm tên hiển thị, số điện thoại, mật khẩu, nhập lại mật khẩu; gợi ý luôn hiện',
      (tester) async {
        await openRegister(tester);
        for (final label in [
          S.fieldDisplayName,
          S.fieldPhone,
          S.fieldPassword,
          S.fieldPasswordConfirm,
        ]) {
          expect(input(label), findsOneWidget, reason: label);
        }
        expect(find.text(S.passwordHint), findsOneWidget);
        expect(find.text(S.registerSubtitle), findsOneWidget);
      },
    );

    testWidgets(
      'P4: nút luôn bấm được; mọi ô sai báo lỗi dưới ô, không gọi server',
      (tester) async {
        await openRegister(tester);
        await fillRegister(
          tester,
          name: '',
          phone: '0912',
          password: randomTestPassword(length: 7),
          confirm: randomTestPassword(length: 3),
        );
        await tapRegisterButton(tester);
        expect(find.text(S.invalidDisplayName), findsOneWidget);
        expect(find.text(S.invalidPhone), findsOneWidget);
        expect(find.text(S.invalidPassword), findsOneWidget);
        expect(
          find.text(S.passwordHint),
          findsNothing,
          reason: 'lỗi thay cho dòng gợi ý',
        );
        expect(find.text(S.invalidPasswordConfirm), findsOneWidget);
        expect(server.calls('POST', '/v1/auth/register'), isEmpty);
      },
    );

    testWidgets('04 §6.13.5: lỗi biến mất khi sửa ô đó', (tester) async {
      await openRegister(tester);
      await fillRegister(tester, name: '');
      await tapRegisterButton(tester);
      expect(find.text(S.invalidDisplayName), findsOneWidget);
      await tester.enterText(input(S.fieldDisplayName), 'M');
      await tester.pump();
      expect(find.text(S.invalidDisplayName), findsNothing);
    });

    testWidgets(
      'số điện thoại hiển thị dạng 0912 345 678, gửi lên chỉ có chữ số',
      (tester) async {
        await openRegister(tester);
        await fillRegister(tester, phone: '0912345678');
        expect(find.text('0912 345 678'), findsOneWidget);
        await tapRegisterButton(tester);
        expect(
          (server.calls('POST', '/v1/auth/register').single.body!
              as Map)['phone'],
          '0912 345 678',
        );
      },
    );

    testWidgets('VS01-T10: đăng ký thành công → S-02, lưu phiên', (
      tester,
    ) async {
      await openRegister(tester);
      await fillRegister(tester);
      await tapRegisterButton(tester);
      expect(find.text(S.disclaimerTitle), findsOneWidget);
      final store = container.read(sessionStoreProvider) as MemorySessionStore;
      expect(store.session!.refreshToken, _refreshToken);
      expect(store.session!.userId, 'u1');
    });

    testWidgets(
      'UX-AC21: số đã có tài khoản → câu lỗi kèm liên kết Đăng nhập',
      (tester) async {
        server.on(
          'POST',
          '/v1/auth/register',
          (_) => (409, _error('phone_taken', 'phone')),
        );
        await openRegister(tester);
        await fillRegister(tester);
        await tapRegisterButton(tester);
        expect(find.textContaining(S.errorPhoneTaken), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: field(S.fieldPhone),
            matching: find.text(S.login),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
      },
    );

    testWidgets('UA-16: không có mạng → "Cần kết nối internet để đăng ký."', (
      tester,
    ) async {
      await openRegister(tester);
      server.offline = true;
      await fillRegister(tester);
      await tapRegisterButton(tester);
      expect(find.text(S.offlineRegister), findsOneWidget);
      expect(find.byType(RegisterScreen), findsOneWidget);
    });

    testWidgets('server từ chối một ô → lỗi dưới đúng ô đó', (tester) async {
      server.on(
        'POST',
        '/v1/auth/register',
        (_) => (422, _error('validation_failed', 'displayName')),
      );
      await openRegister(tester);
      await fillRegister(tester);
      await tapRegisterButton(tester);
      expect(find.text(S.invalidDisplayName), findsOneWidget);
    });

    testWidgets('nút hiện/ẩn mật khẩu có nhãn đọc được (04 §6.17)', (
      tester,
    ) async {
      await openRegister(tester);
      expect(find.byTooltip(S.showPassword), findsNWidgets(2));
      await tester.tap(find.byTooltip(S.showPassword).first);
      await tester.pump();
      expect(find.byTooltip(S.hidePassword), findsOneWidget);
    });
  });

  group('S-01b', () {
    Future<void> openLogin(WidgetTester tester) async {
      await pumpSignedOut(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, S.login));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    }

    Future<void> login(
      WidgetTester tester, {
      String phone = '0912345678',
      String? password,
    }) async {
      await tester.enterText(input(S.fieldPhone), phone);
      await tester.enterText(
        input(S.fieldPassword),
        password ?? randomTestPassword(),
      );
      await tester.tap(find.widgetWithText(FilledButton, S.login));
    }

    testWidgets('đúng → vào S-02 (tài khoản chưa thiết lập, OB-6)', (
      tester,
    ) async {
      await openLogin(tester);
      await login(tester);
      await tester.pumpAndSettle();
      expect(find.text(S.disclaimerTitle), findsOneWidget);
    });

    testWidgets('OB-6, UX-AC4: tài khoản đã thiết lập, máy chưa có dữ liệu → '
        'S-07 khôi phục → Hôm nay kèm "Đã khôi phục dữ liệu"', (tester) async {
      server
        ..on(
          'GET',
          '/v1/me',
          (_) => (200, {..._me(), 'onboardingState': 'completed'}),
        )
        ..on(
          'GET',
          '/v1/sync/pull',
          (_) => (
            200,
            {
              'changes': [
                {
                  'entity': 'profile',
                  'key': 'me',
                  'deleted': false,
                  'serverVersion': 3,
                  'data': const ProfileCodec().encode(completedProfile()),
                },
              ],
              'nextCursor': 3,
              'hasMore': false,
              'remaining': 0,
              'meta': {'serverTime': '2026-10-07T11:42:00.000Z'},
            },
          ),
        );
      await openLogin(tester);
      await login(tester);
      await tester.pumpAndSettle();
      expect(find.text(S.tabToday), findsWidgets);
      expect(find.text(S.restored), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('sai → câu chung; bị chặn (429) → cùng câu chung (TAC-15)', (
      tester,
    ) async {
      server.on(
        'POST',
        '/v1/auth/login',
        (_) => (401, _error('invalid_credentials')),
      );
      await openLogin(tester);
      await login(tester);
      await tester.pumpAndSettle();
      expect(find.text(S.errorInvalidCredentials), findsOneWidget);

      server.on(
        'POST',
        '/v1/auth/login',
        (_) => (429, _error('too_many_attempts')),
      );
      await tester.tap(find.widgetWithText(FilledButton, S.login));
      await tester.pumpAndSettle();
      expect(find.text(S.errorInvalidCredentials), findsOneWidget);
    });

    testWidgets(
      'số sai định dạng hoặc thiếu mật khẩu → câu chung, không gọi server',
      (tester) async {
        await openLogin(tester);
        await login(tester, phone: '0912', password: '');
        await tester.pumpAndSettle();
        expect(find.text(S.errorInvalidCredentials), findsOneWidget);
        expect(server.calls('POST', '/v1/auth/login'), isEmpty);
      },
    );

    testWidgets('không có mạng → "Cần kết nối internet để đăng nhập."', (
      tester,
    ) async {
      await openLogin(tester);
      server.offline = true;
      await login(tester);
      await tester.pumpAndSettle();
      expect(find.text(S.offlineLogin), findsOneWidget);
    });

    testWidgets(
      'đang đăng nhập → nút thành vòng xoay, bấm lặp không gửi thêm',
      (tester) async {
        server.on('POST', '/v1/auth/login', (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return (200, _pair());
        });
        await openLogin(tester);
        await login(tester);
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byKey(const ValueKey('button-spinner')), findsOneWidget);
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expect(server.calls('POST', '/v1/auth/login'), hasLength(1));
      },
    );

    testWidgets(
      'S-01c: Quên mật khẩu? mở bảng trượt có lớp mờ, "Đã hiểu" đóng lại',
      (tester) async {
        await openLogin(tester);
        await tester.tap(find.text(S.forgotPassword));
        await tester.pumpAndSettle();
        expect(find.text(S.forgotPasswordBody), findsOneWidget);
        expect(find.text(S.forgotPasswordNote), findsOneWidget);
        expect(
          find.byType(LoginScreen),
          findsOneWidget,
          reason: 'UR-16: trang phía sau giữ nguyên',
        );
        final barrier = tester
            .widgetList<ModalBarrier>(find.byType(ModalBarrier))
            .last;
        expect(barrier.color, AppPalette.light.scrim);
        await tester.tap(find.widgetWithText(FilledButton, S.understood));
        await tester.pumpAndSettle();
        expect(find.text(S.forgotPasswordBody), findsNothing);
      },
    );

    testWidgets('TA-10: phiên hết hạn → mở S-01b, điền sẵn số của tài khoản', (
      tester,
    ) async {
      await pumpSignedOut(
        tester,
        session: const StoredSession(userId: 'u1', phone: '0912345678'),
      );
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('0912 345 678'), findsOneWidget);
    });
  });
}
