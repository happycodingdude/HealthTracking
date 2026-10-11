import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

/// Nền Bản 2 phía server (06 Bản 2 VS-20, VS20-T11).
void main() {
  late TestApp app;
  late String token;
  // 05:00 UTC thứ 4 14/10/2026 = 12:00 giờ Việt Nam.
  final t0 = DateTime.utc(2026, 10, 14, 5);
  final accepted = DateTime.utc(2026, 10, 7, 9, 50);

  setUp(() async {
    app = await TestApp.create(now: t0.add(const Duration(minutes: 1)));
    token = (await app.register()).accessToken;
  });
  tearDown(() => app.dispose());

  Profile completed({LocalDate? setupDate, LocalDate? scheduleStartedOn}) =>
      Profile(
        onboardingStep: 5,
        disclaimerAcceptedAt: accepted,
        heightCm: 175,
        birthYear: 1996,
        sex: Sex.male,
        activityLevel: ActivityLevel.moderate,
        calorieMode: CalorieMode.auto,
        calorieKcal: 2210,
        setupDate: setupDate ?? LocalDate(2026, 10, 7),
        scheduleStartedOn: scheduleStartedOn,
        onboardingCompletedAt: accepted,
        timezone: 'Asia/Ho_Chi_Minh',
      );

  SyncMutation profile(Profile p, {required DateTime at}) => mutation(
    'profile',
    'me',
    SyncOp.upsert,
    at: at,
    data: const ProfileCodec().encode(p),
  );

  final template = WeeklyTemplate({
    3: TemplateDay(
      enabled: true,
      time: LocalTime(18, 0),
      muscles: const [MuscleGroup.back],
    ),
    5: TemplateDay(
      enabled: true,
      time: LocalTime(18, 0),
      muscles: const [MuscleGroup.shoulders],
    ),
  });

  SyncMutation templateUpsert({required DateTime at}) => mutation(
    'weekly_template',
    'me',
    SyncOp.upsert,
    at: at,
    data: const WeeklyTemplateCodec().encode(template),
  );

  Future<PushResult> pushOne(SyncMutation m) async =>
      (await app.push(token, [m])).results.single;

  Future<MeResponse> me({String? version}) async => MeResponse.fromJson(
    (await app.send(
      'GET',
      '/v1/me',
      token: token,
      headers: {'x-app-version': ?version},
    )).json,
  );

  Future<Profile> pulledProfile() async {
    final change = (await app.pull(
      token,
    )).changes.singleWhere((c) => c.entity == 'profile');
    return const ProfileCodec().decode(change.data!);
  }

  group('TAC2-02, TD2-04: /v1/me theo phiên bản app', () {
    test('tài khoản "Để sau" lịch tuần: app Bản 1 (không header) → bước 4; '
        'app Bản 2 → hoàn tất', () async {
      await pushOne(profile(completed(), at: t0));
      final v1 = await me();
      expect(
        (v1.onboardingState, v1.onboardingStep),
        (OnboardingState.inProgress, 4),
      );
      final v2 = await me(version: '2.0.0');
      expect(
        (v2.onboardingState, v2.onboardingStep),
        (OnboardingState.completed, null),
      );
      final later = await me(version: '2.3.1');
      expect(later.onboardingState, OnboardingState.completed);
    });

    test(
      'header sai định dạng hoặc thấp hơn 2.0.0 được coi như app Bản 1',
      () async {
        await pushOne(profile(completed(), at: t0));
        expect((await me(version: 'abc')).onboardingStep, 4);
        expect((await me(version: '1.9.9')).onboardingStep, 4);
      },
    );

    test('đã có lịch tuần → mọi phiên bản đều hoàn tất', () async {
      await pushOne(profile(completed(), at: t0));
      await pushOne(templateUpsert(at: t0.add(const Duration(seconds: 1))));
      expect((await me()).onboardingState, OnboardingState.completed);
      expect(
        (await me(version: '2.0.0')).onboardingState,
        OnboardingState.completed,
      );
    });
  });

  group('TA2-11: setup_date và schedule_started_on ghi một lần', () {
    test('setup_date đã có thì giữ, bỏ qua giá trị mới', () async {
      await pushOne(profile(completed(), at: t0));
      final r = await pushOne(
        profile(
          completed(setupDate: LocalDate(2026, 10, 20)),
          at: t0.add(const Duration(seconds: 1)),
        ),
      );
      expect(r.status, PushStatus.applied);
      expect((await pulledProfile()).setupDate, LocalDate(2026, 10, 7));
    });

    test('app Bản 1 (không gửi scheduleStartedOn) không xóa được ngày bắt '
        'đầu lịch', () async {
      await pushOne(
        profile(completed(scheduleStartedOn: LocalDate(2026, 10, 14)), at: t0),
      );
      final data = const ProfileCodec().encode(completed())
        ..remove('scheduleStartedOn');
      await pushOne(
        mutation(
          'profile',
          'me',
          SyncOp.upsert,
          at: t0.add(const Duration(seconds: 1)),
          data: data,
        ),
      );
      expect(
        (await pulledProfile()).scheduleStartedOn,
        LocalDate(2026, 10, 14),
      );
    });

    test('ngày bắt đầu lịch trước khi hoàn tất thiết lập → rejected', () async {
      final r = await pushOne(
        profile(
          Profile(
            onboardingStep: 2,
            disclaimerAcceptedAt: accepted,
            scheduleStartedOn: LocalDate(2026, 10, 14),
          ),
          at: t0,
        ),
      );
      expect((r.status, r.field), (PushStatus.rejected, 'scheduleStartedOn'));
    });
  });

  group('05 Bản 2 §6.6.5: server tự ghi schedule_started_on', () {
    test('lịch tuần đầu tiên của tài khoản đã hoàn tất thiết lập (đã "Để '
        'sau") → ngày lưu theo giờ trong hồ sơ; hồ sơ được pull lại', () async {
      await pushOne(profile(completed(), at: t0));
      final before = (await app.pull(token)).nextCursor;
      // 17:30 UTC thứ 4 = 00:30 thứ 5 15/10 giờ Việt Nam.
      final saveAt = DateTime.utc(2026, 10, 14, 17, 30);
      app.clock.set(saveAt.add(const Duration(minutes: 1)));
      // Access token cũ đã hết hạn sau 12 giờ: đăng nhập lại.
      token = TokenPair.fromJson(
        (await app.post('/v1/auth/login', {
          'phone': '0912345678',
          'password': 'matkhau123',
        })).json,
      ).accessToken;
      expect(
        (await pushOne(templateUpsert(at: saveAt))).status,
        PushStatus.applied,
      );
      final changes = (await app.pull(token, cursor: before)).changes;
      final p = changes.singleWhere((c) => c.entity == 'profile');
      expect(
        const ProfileCodec().decode(p.data!).scheduleStartedOn,
        LocalDate(2026, 10, 15),
      );
      // Lưu lại lịch tuần lần sau không đổi ngày bắt đầu.
      await pushOne(templateUpsert(at: saveAt.add(const Duration(days: 3))));
      expect(
        (await pulledProfile()).scheduleStartedOn,
        LocalDate(2026, 10, 15),
      );
    });

    test('tài khoản Bản 1 (lưu lịch ở bước 4, trước khi hoàn tất) → để trống, '
        'mốc tiến độ vẫn là setup_date', () async {
      await pushOne(
        profile(
          Profile(
            onboardingStep: 4,
            disclaimerAcceptedAt: accepted,
            heightCm: 175,
            birthYear: 1996,
            sex: Sex.male,
            activityLevel: ActivityLevel.moderate,
            calorieMode: CalorieMode.auto,
            calorieKcal: 2210,
            timezone: 'Asia/Ho_Chi_Minh',
          ),
          at: t0,
        ),
      );
      await pushOne(templateUpsert(at: t0.add(const Duration(seconds: 1))));
      await pushOne(
        profile(completed(), at: t0.add(const Duration(seconds: 2))),
      );
      // Sửa lịch tuần sau khi đã hoàn tất: không phải lần đầu.
      await pushOne(templateUpsert(at: t0.add(const Duration(seconds: 3))));
      final p = await pulledProfile();
      expect(p.scheduleStartedOn, isNull);
      expect(p.scheduleStart, LocalDate(2026, 10, 7));
    });
  });

  group('VS20-T08: pull dòng dùng chung (exercises, dish_images)', () {
    Future<void> insertExercise(String id, String name) => app.tdb.pool.execute(
      Sql.named('''
        INSERT INTO exercises (id, muscle_group, muscle_region, equipment, logs_weight, name_vi,
                               youtube_video_id, video_channel, video_duration_s, guide_steps,
                               guide_safety, approved_at, sort_order, library_version, server_version)
        VALUES (@id, 'chest', 'chest_upper', 'machine', true, @name, 'TrTSvn5-MTk',
                'Renaissance Periodization', 48, ARRAY['a','b','c'], ARRAY['x','y'],
                '2026-10-11', 1, 1, nextval('sync_version_seq'))'''),
      parameters: {'id': id, 'name': name},
    );

    test('mọi tài khoản nhận dòng dùng chung; cursor không bỏ sót xen kẽ dòng '
        'của tài khoản', () async {
      await insertExercise('chest-upper-machine-a', 'Đẩy ngực trên với máy');
      await pushOne(profile(completed(), at: t0));
      await app.tdb.pool.execute(
        Sql.named('''
          INSERT INTO dish_images (name_key, display_name, file_path, width, height, bytes,
                                   provider, model, quality, server_version)
          VALUES ('phở bò', 'Phở bò', 'dish/x.jpg', 768, 768, 90000, 'fake', 'm', 'low',
                  nextval('sync_version_seq'))'''),
      );

      final other = (await app.register(phone: '0987654321')).accessToken;
      for (final t in [token, other]) {
        final pull = await app.pull(t);
        final entities = [for (final c in pull.changes) c.entity];
        expect(entities, containsAll(['exercise', 'dish_image']));
      }

      // Trang 1 phần tử một: đủ cả 3 dòng, đúng thứ tự server_version.
      final seen = <String>[];
      var cursor = 0;
      while (true) {
        final page = await app.pull(token, cursor: cursor, limit: 1);
        seen.addAll(page.changes.map((c) => c.entity));
        cursor = page.nextCursor;
        if (!page.hasMore) break;
      }
      expect(seen.where((e) => e != 'account'), [
        'exercise',
        'profile',
        'dish_image',
      ]);

      final exercise = (await app.pull(
        token,
      )).changes.singleWhere((c) => c.entity == 'exercise');
      expect(exercise.key, 'chest-upper-machine-a');
      expect(exercise.deleted, isFalse);
      expect(exercise.data, containsPair('muscleRegion', 'chest_upper'));
      expect(exercise.data, containsPair('guideSteps', ['a', 'b', 'c']));
      expect(exercise.data, containsPair('approvedAt', '2026-10-11'));
      expect(exercise.data, containsPair('videoDurationS', 48));
      expect(exercise.data, isNot(contains('libraryVersion')));
      final image = (await app.pull(
        token,
      )).changes.singleWhere((c) => c.entity == 'dish_image');
      expect(image.key, 'phở bò');
      expect(image.data!.keys, {
        'id',
        'nameKey',
        'displayName',
        'width',
        'height',
        'bytes',
        'createdAt',
      });
    });

    test('app gửi lên entity dùng chung → rejected (chỉ pull)', () async {
      await insertExercise('chest-upper-machine-a', 'Đẩy ngực trên với máy');
      final r = await pushOne(
        mutation(
          'exercise',
          'chest-upper-machine-a',
          SyncOp.upsert,
          at: t0,
          data: const {'nameVi': 'Đổi tên'},
        ),
      );
      expect((r.status, r.field), (PushStatus.rejected, 'op'));
      expect(r.current?.key, 'chest-upper-machine-a');
    });
  });

  test('ED2-02: log request kèm phiên bản app', () async {
    await app.send(
      'GET',
      '/v1/me',
      token: token,
      headers: {'x-app-version': '2.0.0'},
    );
    await app.send('GET', '/v1/me', token: token);
    final lines = [
      for (final l in app.log.lines)
        if ((jsonDecode(l) as Map)['path'] == '/v1/me') jsonDecode(l) as Map,
    ];
    expect(lines.first['appVersion'], '2.0.0');
    expect(lines.last.containsKey('appVersion'), isFalse);
  });
}
