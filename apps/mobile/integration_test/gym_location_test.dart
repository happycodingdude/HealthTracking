// Vị trí phòng gym trên simulator (06 Bản 5 VS58-T06, demo VS-58): quyền
// "Luôn luôn" và vị trí giả do tool/integration_test.sh đặt bằng `simctl`
// (TA5-12, IA5-10); trong lúc chạy, script dời vị trí qua lại giữa hai điểm
// cách nhau > 200 m để iOS báo "vào vùng". Kiểm qua `GymRegionMonitor` thật:
// "Lưu vị trí này" → lấy vị trí → theo dõi vùng 150 m → vào vùng → Dart ghi
// `gym_arrivals(hôm nay)` (F32-AC1, AC4, R8; §6.4.2 phần trên máy).
import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:domain/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/data/auth/session_store.dart';
import 'package:mobile/data/db/open_database.dart';
import 'package:mobile/data/sync/sync_providers.dart';
import 'package:mobile/features/auth/presentation/login_screen.dart';
import 'package:mobile/features/me/application/gym_location.dart';
import 'package:mobile/features/me/data/account_repository.dart';
import 'package:mobile/features/me/data/profile_repository.dart';
import 'package:mobile/features/native/gym_region_bridge.dart';
import 'package:mobile/main.dart' as app;
import 'package:package_info_plus/package_info_plus.dart';

import 'flow_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('VS-58: S-77 lưu vị trí (quyền Luôn luôn) → theo dõi vùng → '
      'vào vùng → gym_arrivals hôm nay; tắt / bật; xóa', (tester) async {
    // Gỡ app không xóa Keychain: phiên của file test trước còn đó.
    await const FlutterSecureStorage().deleteAll();
    final auth = ProviderContainer(
      overrides: [
        appVersionProvider.overrideWithValue(
          AppVersion.parse((await PackageInfo.fromPlatform()).version),
        ),
      ],
    );
    await auth
        .read(authRepositoryProvider)
        .register(
          RegisterRequest(
            displayName: 'Lan',
            phone: '0977777777',
            password: randomTestPassword(),
          ),
        );
    auth.dispose();
    final now = DateTime.now();
    final db = openAppDatabase();
    await AccountRepository(db).put('Lan');
    await ProfileRepository(db).put(
      Profile(
        onboardingStep: 5,
        disclaimerAcceptedAt: now.subtract(const Duration(days: 2)),
        heightCm: 175,
        birthYear: 1996,
        sex: Sex.male,
        activityLevel: ActivityLevel.moderate,
        calorieMode: CalorieMode.auto,
        calorieKcal: 2210,
        setupDate: LocalDate.fromDateTime(now).addDays(-2),
        onboardingCompletedAt: now.subtract(const Duration(days: 2)),
        remindersEnabled: false,
        timezone: 'Asia/Ho_Chi_Minh',
      ),
    );
    await db.close();

    await app.runIronlyApp();
    await pumpUntil(tester, tabLabel(S.tabMe));
    await tester.tap(tabLabel(S.tabMe));
    await tester.pump(const Duration(seconds: 1));
    await pumpUntil(tester, find.byKey(const ValueKey('row-gym-location')));
    await tapVisible(tester, find.byKey(const ValueKey('row-gym-location')));
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('gym-card'))),
    );
    final bridge = container.read(gymRegionBridgeProvider);
    // Script cấp quyền ngay sau khi app được cài: chờ tối đa 20 giây.
    for (var i = 0; i < 40; i++) {
      if (await bridge.authorizationStatus() == LocationAccess.always) break;
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(await bridge.authorizationStatus(), LocationAccess.always);
    container.invalidate(locationAccessProvider);

    // F32-AC1: lưu → "Lưu lúc …", công tắc bật, theo dõi vùng.
    await tester.tap(find.byKey(const ValueKey('gym-save')));
    await pumpUntil(tester, find.byKey(const ValueKey('gym-saved-at')));
    expect(find.text(S.locationAlways), findsOneWidget);
    final repo = container.read(gymLocationRepositoryProvider);
    expect((await repo.get())?.enabled, isTrue);

    // Vào vùng (script dời vị trí qua lại) → gym_arrivals hôm nay.
    final today = LocalDate.fromDateTime(DateTime.now());
    final watch = Stopwatch()..start();
    while (!await repo.arrived(today)) {
      if (watch.elapsed > const Duration(seconds: 90)) {
        fail('iOS chưa báo vào vùng sau 90 giây');
      }
      await tester.pump(const Duration(milliseconds: 500));
    }
    debugPrint('VS-58 demo: vào vùng sau ${watch.elapsed.inSeconds} giây');

    // F32-AC4: tắt → vị trí giữ; bật lại.
    await tester.tap(find.byKey(const ValueKey('gym-switch')));
    await tester.pumpAndSettle();
    expect((await repo.get())?.enabled, isFalse);
    await tester.tap(find.byKey(const ValueKey('gym-switch')));
    await tester.pumpAndSettle();
    expect((await repo.get())?.enabled, isTrue);

    // F32-R8: xóa → về chưa lưu (ngừng theo dõi để kịch bản sau không bị
    // ảnh hưởng).
    await tapVisible(tester, find.byKey(const ValueKey('gym-delete')));
    await tester.tap(find.byKey(const ValueKey('confirm-delete-gym')));
    await pumpUntil(tester, find.byKey(const ValueKey('gym-save')));
    expect(await repo.get(), isNull);

    // Lưu lại rồi đăng xuất (F32-E3): ngừng theo dõi, xóa dữ liệu trên máy —
    // kịch bản sau bắt đầu từ máy sạch.
    await tester.tap(find.byKey(const ValueKey('gym-save')));
    await pumpUntil(tester, find.byKey(const ValueKey('gym-saved-at')));
    // Chạm tab đang mở → về S-50 (NAV-15).
    await tester.tap(tabLabel(S.tabMe));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('row-account-data')));
    await tapVisible(tester, find.byKey(const ValueKey('row-logout')));
    await tester.tap(find.byKey(const ValueKey('logout-confirm')));
    await pumpUntil(tester, find.byType(LoginScreen));
    expect(await SecureSessionStore().read(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
