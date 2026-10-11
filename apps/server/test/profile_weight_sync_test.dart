import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

void main() {
  late TestApp app;
  late String token;
  // 10:00 UTC thứ 4 07/10/2026 = 17:00 giờ Việt Nam.
  final t0 = DateTime.utc(2026, 10, 7, 9, 59);
  final accepted = DateTime.utc(2026, 10, 7, 9, 50);

  setUp(() async {
    app = await TestApp.create();
    token = (await app.register()).accessToken;
  });
  tearDown(() => app.dispose());

  Profile body({int step = 3}) => Profile(
    onboardingStep: step,
    disclaimerAcceptedAt: accepted,
    heightCm: 175,
    birthYear: 1996,
    sex: Sex.male,
    activityLevel: ActivityLevel.moderate,
    timezone: 'Asia/Ho_Chi_Minh',
  );

  SyncMutation profile(Profile p, {DateTime? at}) => mutation(
    'profile',
    'me',
    SyncOp.upsert,
    at: at ?? t0,
    data: const ProfileCodec().encode(p),
  );

  SyncMutation weight(String week, int kgX10, {DateTime? at}) => mutation(
    'weight',
    week,
    SyncOp.upsert,
    at: at ?? t0,
    data: {'weightKgX10': kgX10},
  );

  Future<PushResult> pushOne(SyncMutation m, {String? as}) async =>
      (await app.push(as ?? token, [m])).results.single;

  Future<MeResponse> me([String? as]) async =>
      MeResponse.fromJson((await app.get('/v1/me', token: as ?? token)).json);

  test('OB-6: /v1/me suy ra onboardingState từ hồ sơ', () async {
    expect((await me()).onboardingState, OnboardingState.notStarted);

    await pushOne(
      profile(Profile(onboardingStep: 2, disclaimerAcceptedAt: accepted)),
    );
    var m = await me();
    expect(
      (m.onboardingState, m.onboardingStep),
      (OnboardingState.inProgress, 2),
    );

    await pushOne(
      profile(
        body(
          step: 4,
        ).copyWith(calorieMode: CalorieMode.auto, calorieKcal: 2210),
        at: t0.add(const Duration(seconds: 1)),
      ),
    );
    m = await me();
    expect(
      (m.onboardingState, m.onboardingStep),
      (OnboardingState.inProgress, 4),
    );

    // Bước 4 lưu lịch tuần như Bản 1. Tài khoản hoàn tất thiết lập mà chưa có
    // lịch ("Để sau", Bản 2) được kiểm ở v2_foundation_test.dart (TD2-04).
    await pushOne(
      mutation(
        'weekly_template',
        'me',
        SyncOp.upsert,
        at: t0.add(const Duration(milliseconds: 1500)),
        data: const WeeklyTemplateCodec().encode(
          WeeklyTemplate({
            1: TemplateDay(
              enabled: true,
              time: LocalTime(18, 0),
              muscles: const [MuscleGroup.chest],
            ),
          }),
        ),
      ),
    );

    await pushOne(
      profile(
        body(step: 5).copyWith(
          calorieMode: CalorieMode.auto,
          calorieKcal: 2210,
          setupDate: LocalDate(2026, 10, 7),
          onboardingCompletedAt: t0,
        ),
        at: t0.add(const Duration(seconds: 2)),
      ),
    );
    expect((await me()).onboardingState, OnboardingState.completed);
  });

  test('hồ sơ khứ hồi qua pull đúng hợp đồng 06 §6.5.1', () async {
    final p = body(
      step: 4,
    ).copyWith(calorieMode: CalorieMode.manual, calorieKcal: 1300);
    expect((await pushOne(profile(p))).status, PushStatus.applied);
    final change = (await app.pull(
      token,
    )).changes.firstWhere((c) => c.entity == 'profile');
    expect(change.key, 'me');
    expect(const ProfileCodec().decode(change.data!), p);
  });

  test('F02-E3, VS11-T04: đề xuất đang chờ khứ hồi qua pull; bỏ đề xuất '
      '(Giữ nguyên) xóa cả số và lý do', () async {
    final p = body(step: 4)
        .copyWith(calorieMode: CalorieMode.manual, calorieKcal: 1900)
        .withPending(2090, CaloriePendingReason.weight);
    expect((await pushOne(profile(p))).status, PushStatus.applied);
    Future<Profile> pulled() async => const ProfileCodec().decode(
      (await app.pull(
        token,
      )).changes.firstWhere((c) => c.entity == 'profile').data!,
    );
    expect(
      (
        (await pulled()).caloriePendingKcal,
        (await pulled()).caloriePendingReason,
      ),
      (2090, CaloriePendingReason.weight),
    );
    final kept = await pushOne(
      profile(
        CalorieRecalc.keepManual(p),
        at: t0.add(const Duration(seconds: 1)),
      ),
    );
    expect(kept.status, PushStatus.applied);
    final after = await pulled();
    expect(
      (after.caloriePendingKcal, after.caloriePendingReason),
      (null, null),
    );
    expect(after.calorieKcal, 1900);
  });

  group('giá trị ngoài khoảng bị rejected (VS03-T12)', () {
    for (final (name, p, field) in [
      ('chiều cao 231', body().copyWith(heightCm: 231), 'heightCm'),
      ('chưa đủ 18 tuổi', body().copyWith(birthYear: 2010), 'birthYear'),
      (
        'qua bước 1 khi chưa bấm "Tôi đã hiểu" (F10-AC1)',
        const Profile(onboardingStep: 2),
        'disclaimerAcceptedAt',
      ),
      (
        'mức tự đặt 799 (F02-V1)',
        body(
          step: 4,
        ).copyWith(calorieMode: CalorieMode.manual, calorieKcal: 799),
        'calorieKcal',
      ),
      (
        'mức Tự động dưới ngưỡng an toàn',
        body(
          step: 4,
        ).copyWith(calorieMode: CalorieMode.auto, calorieKcal: 1400),
        'calorieKcal',
      ),
      (
        'VS11-T04: đề xuất có số nhưng thiếu lý do',
        body(step: 4)
            .copyWith(calorieMode: CalorieMode.manual, calorieKcal: 1900)
            .withPending(2090, null),
        'caloriePendingKcal',
      ),
      (
        'VS11-T04: đề xuất ở chế độ Tự động (F02-R8 không đề xuất)',
        body(step: 4)
            .copyWith(calorieMode: CalorieMode.auto, calorieKcal: 2210)
            .withPending(2090, CaloriePendingReason.weight),
        'caloriePendingKcal',
      ),
    ]) {
      test(name, () async {
        final r = await pushOne(profile(p));
        expect(
          (r.status, r.code, r.field),
          (PushStatus.rejected, ErrorCode.validationFailed, field),
        );
      });
    }

    test('enum lạ → rejected theo tên trường', () async {
      final data = const ProfileCodec().encode(body())..['sex'] = 'other';
      final r = await pushOne(
        mutation('profile', 'me', SyncOp.upsert, at: t0, data: data),
      );
      expect((r.status, r.field), (PushStatus.rejected, 'sex'));
    });

    test('cân: ngoài 30–250 kg, không phải thứ 2, tuần tương lai', () async {
      expect((await pushOne(weight('2026-10-05', 299))).field, 'weightKgX10');
      expect((await pushOne(weight('2026-10-05', 2501))).field, 'weightKgX10');
      expect((await pushOne(weight('2026-10-06', 725))).field, 'key');
      expect((await pushOne(weight('2026-10-12', 725))).field, 'key');
      expect(
        (await pushOne(weight('2026-10-05', 725))).status,
        PushStatus.applied,
      );
    });

    test(
      'cân: chủ nhật 23:30 giờ Việt Nam (16:30 UTC) không bị coi là tuần '
      'tương lai; thứ 2 00:30 (17:30 UTC chủ nhật) ghi được cho tuần mới',
      () async {
        final sundayNight = DateTime.utc(2026, 10, 11, 16, 30);
        app.clock.set(sundayNight);
        final c = (await app.register(phone: '0933333333')).accessToken;
        expect(
          (await pushOne(
            weight('2026-10-05', 725, at: sundayNight),
            as: c,
          )).status,
          PushStatus.applied,
        );
        final mondayEarly = DateTime.utc(2026, 10, 11, 17, 30);
        app.clock.set(mondayEarly);
        // Token 15 phút đã hết hạn sau khi tua đồng hồ: dùng tài khoản khác.
        final d = (await app.register(phone: '0944444444')).accessToken;
        expect(
          (await pushOne(
            weight('2026-10-12', 724, at: mondayEarly),
            as: d,
          )).status,
          PushStatus.applied,
        );
      },
    );
  });

  test('cân: ghi, thay, xóa (tombstone đến được máy khác)', () async {
    await pushOne(weight('2026-09-28', 752));
    await pushOne(weight('2026-10-05', 750));
    await pushOne(
      weight('2026-10-05', 746, at: t0.add(const Duration(minutes: 1))),
    );
    var changes = (await app.pull(
      token,
    )).changes.where((c) => c.entity == 'weight');
    expect(
      [for (final c in changes) (c.key, c.data?['weightKgX10'])],
      [('2026-09-28', 752), ('2026-10-05', 746)],
    );
    final cursor = (await app.pull(token)).nextCursor;
    await pushOne(
      mutation(
        'weight',
        '2026-10-05',
        SyncOp.delete,
        at: t0.add(const Duration(minutes: 2)),
      ),
    );
    changes = (await app.pull(token, cursor: cursor)).changes;
    expect(
      [for (final c in changes) (c.entity, c.key, c.deleted)],
      [('weight', '2026-10-05', true)],
    );
  });

  test('F07-AC5, F07-R3: xóa số cân duy nhất còn lại → rejected', () async {
    await pushOne(weight('2026-10-05', 750));
    final r = await pushOne(
      mutation(
        'weight',
        '2026-10-05',
        SyncOp.delete,
        at: t0.add(const Duration(minutes: 1)),
      ),
    );
    expect((r.status, r.field), (PushStatus.rejected, 'key'));
    final rows = await app.tdb.pool.execute(
      "SELECT weight_kg_x10, deleted FROM weights WHERE week_start = '2026-10-05'",
    );
    expect(rows.single, [750, false]);
  });

  test('F07-R2: đã thiết lập (tuần 05/10) → ghi tuần 28/09 bị rejected; tuần '
      'thiết lập được', () async {
    final completed = body(step: 5).copyWith(
      calorieMode: CalorieMode.auto,
      calorieKcal: 2210,
      setupDate: LocalDate(2026, 10, 7),
      onboardingCompletedAt: accepted,
    );
    expect((await pushOne(profile(completed))).status, PushStatus.applied);
    final before = await pushOne(weight('2026-09-28', 750));
    expect((before.status, before.field), (PushStatus.rejected, 'key'));
    expect(
      (await pushOne(weight('2026-10-05', 750))).status,
      PushStatus.applied,
    );
  });

  group('TAC-07: truy cập chéo tài khoản', () {
    test('B không đọc, không ghi được hồ sơ và cân của A', () async {
      await pushOne(profile(body()));
      await pushOne(weight('2026-10-05', 725));
      final b = (await app.register(
        phone: '0922222222',
        name: 'Bình',
      )).accessToken;

      final pulled = (await app.pull(b)).changes;
      expect([for (final c in pulled) c.entity], ['account']);
      expect((await me(b)).onboardingState, OnboardingState.notStarted);

      await pushOne(profile(body().copyWith(heightCm: 160)), as: b);
      await pushOne(weight('2026-10-05', 600), as: b);
      final mine = (await app.pull(token)).changes;
      expect(
        const ProfileCodec()
            .decode(mine.firstWhere((c) => c.entity == 'profile').data!)
            .heightCm,
        175,
      );
      expect(mine.firstWhere((c) => c.entity == 'weight').data, {
        'weightKgX10': 725,
      });
    });
  });
}
