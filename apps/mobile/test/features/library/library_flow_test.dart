import 'dart:convert';

import 'package:api_contract/api_contract.dart' show AiBudgetMeta;
import 'package:domain/domain.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/router.dart';
import 'package:mobile/app/shell/app_tab_bar.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/app/time_ticker.dart';
import 'package:mobile/core/formatters.dart';
import 'package:mobile/core/widgets/reference_tag.dart';
import 'package:mobile/data/db/app_database.dart' hide ExerciseRow;
import 'package:mobile/features/library/data/video_player_gateway.dart';
import 'package:mobile/features/library/presentation/exercise_screen.dart';
import 'package:mobile/features/library/presentation/library_screen.dart';
import 'package:mobile/features/me/data/account_repository.dart';
import 'package:mobile/features/me/data/profile_repository.dart';
import 'package:mobile/features/progress/presentation/progress_screen.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';
import 'package:mobile/features/schedule/presentation/schedule_screen.dart';

import '../../support/app_harness.dart';
import '../../support/fake_server.dart';
import '../../support/library_fixture.dart';
import '../../support/schedule_fixture.dart';

void main() {
  late AppDatabase db;
  late FakeConnectivity connectivity;
  late FakeVideoGateway video;
  late ProviderContainer container;
  late List<Exercise> library;

  // templateAc2: thứ 4 tập Lưng. 10:00 thứ 4 14/10.
  final wed14 = DateTime(2026, 10, 14, 10);
  // Thứ 3 13/10: ngày nghỉ.
  final tue13 = DateTime(2026, 10, 13, 10);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    connectivity = FakeConnectivity();
    video = FakeVideoGateway();
    library = realLibrary();
  });

  Finder tabBarText(String text) =>
      find.descendant(of: find.byType(AppTabBar), matching: find.text(text));

  /// Dựng cả app ở [now], mở tab Tập luyện. [tall]: màn hình cao để S-67
  /// dựng đủ mọi phần (danh sách chỉ dựng phần gần khung nhìn).
  Future<void> pump(
    WidgetTester tester, {
    DateTime? now,
    bool tall = false,
  }) async {
    tester.view
      ..physicalSize = Size(390 * 3, (tall ? 2400 : 844) * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        ...appOverrides(
          db: db,
          clock: FixedClock(now ?? wed14),
          server: FakeServer(),
          connectivity: connectivity,
        ),
        videoPlayerGatewayProvider.overrideWithValue(video),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const IronlyApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(tabBarText(S.tabTraining));
    await tester.pumpAndSettle();
  }

  /// Chạm [key]; phần tử có thể đang nằm ngoài khung nhìn (đã dựng sẵn).
  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(ValueKey(key), skipOffstage: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  /// Thanh chọn mục của mục đang hiện. S-20 tự cuộn tới hôm nay nên thanh
  /// có thể đã ra khỏi vùng dựng sẵn của danh sách → cuộn lên.
  Future<Finder> sectionBar(WidgetTester tester, String section) async {
    final f = find.byKey(ValueKey('section-$section'));
    if (f.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        f,
        -300,
        scrollable: find
            .descendant(
              of: find.byType(ScheduleScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    return f;
  }

  Future<void> selectSection(WidgetTester tester, String section) async {
    await tester.tap(await sectionBar(tester, section));
    await tester.pumpAndSettle();
  }

  /// Mở S-66 (mục Bài tập).
  Future<void> openLibrary(WidgetTester tester) =>
      selectSection(tester, 'library');

  /// Mở S-67 của [e] như chạm dòng bài ở S-66 (nhóm của bài đang chọn).
  Future<void> openExercise(WidgetTester tester, Exercise e) async {
    await openLibrary(tester);
    await tapKey(tester, 'group-${e.group.name}');
    await tapKey(tester, 'exercise-${e.id}');
  }

  /// Tiêu đề vùng ở S-66 theo thứ tự từ trên xuống.
  List<String> regionHeaders(WidgetTester tester) {
    final found =
        find
            .descendant(
              of: find.byType(LibraryScreen),
              matching: find.byWidgetPredicate(
                (w) =>
                    w.key is ValueKey<String> &&
                    (w.key! as ValueKey<String>).value.startsWith('region-'),
              ),
              skipOffstage: false,
            )
            .evaluate()
            .toList()
          ..sort(
            (a, b) => tester
                .getTopLeft(find.byWidget(a.widget))
                .dy
                .compareTo(tester.getTopLeft(find.byWidget(b.widget)).dy),
          );
    return [
      for (final e in found)
        (e.widget.key! as ValueKey<String>).value.substring(7),
    ];
  }

  /// Bài ở S-66 theo thứ tự từ trên xuống.
  List<String> rows(WidgetTester tester) {
    final found =
        find
            .descendant(
              of: find.byType(LibraryScreen),
              matching: find.byType(ExerciseRow),
              skipOffstage: false,
            )
            .evaluate()
            .toList()
          ..sort(
            (a, b) => tester
                .getTopLeft(find.byWidget(a.widget))
                .dy
                .compareTo(tester.getTopLeft(find.byWidget(b.widget)).dy),
          );
    return [for (final e in found) (e.widget as ExerciseRow).exercise.id];
  }

  /// Màn đang hiện không có lối thêm, sửa, xóa bài (F18-AC7).
  void expectReadOnly() {
    for (final icon in [
      Icons.add,
      Icons.add_circle,
      Icons.edit,
      Icons.edit_outlined,
      Icons.delete,
      Icons.delete_outline,
    ]) {
      expect(find.byIcon(icon), findsNothing, reason: '$icon');
    }
    for (final word in ['Thêm', 'Sửa', 'Xóa']) {
      expect(find.textContaining(word), findsNothing, reason: word);
    }
  }

  group('tab Tập luyện (UX-AC30, VS23-T01)', () {
    testWidgets('tab thứ nhất tên "Tập luyện" với 3 mục Lịch | Bài tập | '
        'Tiến bộ, mặc định Lịch; nút "Lịch tuần" chỉ ở mục Lịch; mục Tiến bộ '
        'trống (S-68); mục đang chọn được nhớ khi đổi tab trong phiên', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await seedSetUp(db);
      await seedLibrary(db);
      await pump(tester);
      expect(tabBarText(S.tabTraining), findsOneWidget);
      expect(find.text('Lịch tập'), findsNothing);
      await sectionBar(tester, 'schedule');
      for (final s in ['schedule', 'library', 'progress']) {
        expect(find.byKey(ValueKey('section-$s')), findsOneWidget);
      }
      expect(find.text(S.sectionSchedule), findsOneWidget);
      expect(find.text(S.sectionLibrary), findsOneWidget);
      expect(find.text(S.sectionProgress), findsOneWidget);
      expect(find.byType(ScheduleScreen), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(const ValueKey('section-schedule'))),
        isSemantics(isSelected: true),
      );

      await openLibrary(tester);
      expect(find.byType(LibraryScreen), findsOneWidget);
      expect(find.byType(ScheduleScreen), findsNothing);
      expect(find.byKey(const ValueKey('open-weekly')), findsNothing);

      await selectSection(tester, 'progress');
      expect(
        find.byKey(const ValueKey('progress-empty')).hitTestable(),
        findsOneWidget,
      );
      expect(find.text(S.progressEmptyTitle), findsOneWidget);
      expect(find.text(S.progressEmptyBody), findsOneWidget);
      expect(find.byKey(const ValueKey('open-weekly')), findsNothing);

      await openLibrary(tester);
      await tester.tap(tabBarText(S.tabToday));
      await tester.pumpAndSettle();
      await tester.tap(tabBarText(S.tabTraining));
      await tester.pumpAndSettle();
      expect(find.byType(LibraryScreen), findsOneWidget, reason: 'nhớ mục');

      await selectSection(tester, 'schedule');
      expect(find.byType(ScheduleScreen), findsOneWidget);
      expect(find.byType(ProgressScreen), findsNothing);
      semantics.dispose();
    });

    testWidgets('UX-AC30, F18-AC5: tài khoản chưa có lịch vẫn có 3 mục; thư '
        'viện dùng bình thường (mặc định Ngực)', (tester) async {
      await AccountRepository(db).put('Minh');
      await ProfileRepository(db).put(completedProfile());
      await seedLibrary(db);
      await pump(tester);
      expect(await sectionBar(tester, 'library'), findsOneWidget);
      await openLibrary(tester);
      expect(regionHeaders(tester), [
        'chest_upper',
        'chest_mid',
        'chest_lower',
      ]);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('cỡ chữ lớn nhất: thanh chọn mục xuống 2 hàng, mỗi mục cao '
        'tối thiểu 44 điểm', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 3.1;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await seedSetUp(db);
      await pump(tester);
      await sectionBar(tester, 'progress');
      await sectionBar(tester, 'schedule');
      final tops = {
        for (final s in ['schedule', 'library', 'progress'])
          tester.getTopLeft(find.byKey(ValueKey('section-$s'))).dy,
      };
      expect(tops, hasLength(2));
      for (final s in ['schedule', 'library', 'progress']) {
        expect(
          tester.getSize(find.byKey(ValueKey('section-$s'))).height,
          greaterThanOrEqualTo(44),
        );
      }
    });
  });

  group('S-66 thư viện (VS23-T04)', () {
    testWidgets('mặc định chọn nhóm cơ đầu tiên của buổi hôm nay (thứ 4: '
        'Lưng); hàng 6 nhóm theo thứ tự Ngực · Lưng · Vai · Tay trước · Tay '
        'sau · Bụng; mỗi nhóm: vùng theo F18-R9, máy trước tạ sau; dòng cuối; '
        'không vòng xoay', (tester) async {
      final semantics = tester.ensureSemantics();
      await seedSetUp(db);
      await seedLibrary(db);
      await pump(tester);
      await openLibrary(tester);
      expect(
        tester.getSemantics(find.byKey(const ValueKey('group-back'))),
        isSemantics(isSelected: true),
      );
      expect(regionHeaders(tester), ['lats', 'back_mid', 'back_lower']);

      final xs = [
        for (final g in LibraryRules.groupOrder)
          tester.getTopLeft(find.byKey(ValueKey('group-${g.name}'))).dx,
      ];
      expect(xs, [...xs]..sort(), reason: 'UA2-14');
      expect(
        [
          for (final g in LibraryRules.groupOrder)
            tester
                .widget<Text>(
                  find.descendant(
                    of: find.byKey(ValueKey('group-${g.name}')),
                    matching: find.byType(Text),
                  ),
                )
                .data,
        ],
        ['Ngực', 'Lưng', 'Vai', 'Tay trước', 'Tay sau', 'Bụng', 'Chân'],
      );

      // Thư viện Bản 2 chưa có bài Chân (28 bài Bản 3 vào ở VS-33).
      for (final g in LibraryRules.groupOrder.where(
        (g) => g != MuscleGroup.legs,
      )) {
        await tapKey(tester, 'group-${g.name}');
        expect(regionHeaders(tester), [
          for (final r in MuscleRegion.of(g)) r.id,
        ], reason: '$g');
        expect(rows(tester), [
          for (final e in library)
            if (e.group == g) e.id,
        ], reason: '$g');
        for (final e in library.where((e) => e.group == g)) {
          final row = find.byKey(ValueKey('exercise-${e.id}'));
          expect(
            find.descendant(of: row, matching: find.text(e.nameVi)),
            findsOneWidget,
          );
          expect(
            find.descendant(of: row, matching: find.text(Fmt.region(e.region))),
            findsOneWidget,
          );
        }
        expect(
          find.text(Fmt.region(MuscleRegion.of(g).first).toUpperCase()),
          findsOneWidget,
        );
      }
      // Máy trước tạ sau trong một vùng.
      await tapKey(tester, 'group-chest');
      expect(
        [
          for (final id in rows(tester).take(2))
            id.contains('-machine-') ? 'machine' : 'free-weight',
        ],
        ['machine', 'free-weight'],
      );
      expect(find.text(S.libraryFootnote, skipOffstage: false), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expectReadOnly();
      semantics.dispose();
    });

    testWidgets('hôm nay không có buổi tập → mặc định Ngực', (tester) async {
      await seedSetUp(db);
      await seedLibrary(db);
      await pump(tester, now: tue13);
      await openLibrary(tester);
      expect(regionHeaders(tester), [
        'chest_upper',
        'chest_mid',
        'chest_lower',
      ]);
    });

    testWidgets('F18-E4: vùng tạm chỉ còn 1 bài → hiện bài còn lại, không có '
        'ghi chú; bài đã rời thư viện không hiện', (tester) async {
      await seedSetUp(db);
      final gone = exerciseOf(library, MuscleRegion.chestUpper, 'free-weight');
      await seedLibrary(db, [
        for (final e in library)
          e.id == gone.id ? e.copyWith(active: false) : e,
      ]);
      await pump(tester, now: tue13);
      await openLibrary(tester);
      expect(
        rows(tester).first,
        exerciseOf(library, MuscleRegion.chestUpper).id,
      );
      expect(rows(tester), isNot(contains(gone.id)));
      expect(rows(tester), hasLength(5));
      expect(find.text(S.notInLibrary), findsNothing);
    });

    testWidgets('F18-AC4: đã chạm trần ngân sách AI → thư viện và chi tiết bài '
        'dùng bình thường', (tester) async {
      await seedSetUp(db);
      await seedLibrary(db);
      await (db.update(db.syncState)..where((s) => s.id.equals(1))).write(
        SyncStateCompanion(
          aiBudget: Value(
            jsonEncode(
              AiBudgetMeta(
                month: YearMonth(2026, 10),
                usedVnd: 50000,
                capVnd: 50000,
                blocked: true,
              ).toJson(),
            ),
          ),
        ),
      );
      await pump(tester);
      final e = exerciseOf(library, MuscleRegion.lats);
      await openExercise(tester, e);
      expect(find.byType(ExerciseScreen), findsOneWidget);
      expect(find.text(e.guideSteps.first), findsOneWidget);
      expect(find.byKey(const ValueKey('video-play')), findsOneWidget);
    });
  });

  group('S-67 chi tiết bài (VS23-T05)', () {
    testWidgets('mở từ thư viện: nút quay lại "Thư viện", khu video chưa tạo '
        'trình phát, tên, dòng phụ, hình lớn + "Vùng cơ chịu tác động chính", '
        'Cách tập đánh số, Lưu ý an toàn, nhãn hướng dẫn; không có khu mức tạ '
        '(F19-AC4), không có lối thêm/sửa/xóa (F18-AC7)', (tester) async {
      await seedSetUp(db);
      await seedLibrary(db);
      await pump(tester, tall: true);
      final e = exerciseOf(library, MuscleRegion.chestUpper, 'machine');
      await openExercise(tester, e);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('exercise-back')),
          matching: find.text(S.backLibrary),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('video-play')), findsOneWidget);
      expect(find.text('0:48'), findsOneWidget);
      expect(video.opened, isEmpty, reason: 'UA2-12: không tự tải');
      expect(find.text(e.nameVi), findsOneWidget);
      expect(find.text('Ngực · Ngực trên'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('body-map-male_front-chest_upper')),
        findsOneWidget,
      );
      expect(find.text(S.mainRegion), findsOneWidget);
      expect(find.text(S.howTo.toUpperCase()), findsOneWidget);
      for (final (i, step) in e.guideSteps.indexed) {
        expect(find.text(step, skipOffstage: false), findsOneWidget);
        expect(find.text('${i + 1}', skipOffstage: false), findsWidgets);
      }
      expect(
        find.text(S.safetyNotes.toUpperCase(), skipOffstage: false),
        findsOneWidget,
      );
      for (final note in e.guideSafety) {
        expect(find.text(note, skipOffstage: false), findsOneWidget);
      }
      expect(
        find.text(S.exerciseGuideNote, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('not-in-library')), findsNothing);
      expect(find.textContaining('Ghi mức tạ'), findsNothing);
      expect(find.textContaining('Xem biểu đồ'), findsNothing);
      expectReadOnly();

      await tapKey(tester, 'exercise-back');
      expect(find.byType(ExerciseScreen), findsNothing);
      expect(find.byType(LibraryScreen), findsOneWidget);
    });

    testWidgets('F19-AC1, F18-AC2: cả 29 bài mở được, đủ video, tên, nhóm · '
        'vùng · dụng cụ, hình vùng cơ, hướng dẫn', (tester) async {
      await seedSetUp(db);
      await seedLibrary(db);
      await pump(tester, tall: true);
      final router = container.read(routerProvider);
      expect(library, hasLength(29));
      for (final e in library) {
        router.go(exercisePath(e.id, ExerciseFrom.library));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('video-play')), findsOneWidget);
        expect(find.text(e.nameVi), findsOneWidget, reason: e.id);
        expect(
          find.text('${Fmt.muscle(e.group)} · ${Fmt.region(e.region)}'),
          findsOneWidget,
          reason: e.id,
        );
        final sex = Sex.male.name;
        expect(
          find.byKey(
            ValueKey('body-map-${sex}_${e.region.view.name}-${e.region.id}'),
          ),
          findsOneWidget,
          reason: e.id,
        );
        for (final line in [...e.guideSteps, ...e.guideSafety]) {
          expect(find.text(line, skipOffstage: false), findsOneWidget);
        }
        expect(
          find.text(S.exerciseGuideNote, skipOffstage: false),
          findsOneWidget,
        );
      }
    });

    testWidgets('5 trạng thái video: chưa phát → chạm → "Đang tải video…" → '
        'đang phát; tải lỗi → câu F18-E3 + "Thử lại" → tải lại; rời màn hình '
        '→ hủy trình phát', (tester) async {
      await seedSetUp(db);
      await seedLibrary(db);
      await pump(tester);
      final e = exerciseOf(library, MuscleRegion.lats, 'machine');
      await openExercise(tester, e);

      await tapKey(tester, 'video-play');
      expect(video.opened, [e.youtubeVideoId]);
      expect(find.byKey(const ValueKey('video-loading')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('video-loading')),
          matching: find.text(S.videoLoading),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('fake-player')), findsOneWidget);
      final player = tester.element(find.byKey(const ValueKey('fake-player')));
      video.ready();
      await tester.pumpAndSettle();
      expect(
        tester.element(find.byKey(const ValueKey('fake-player'))),
        same(player),
        reason: 'trình phát không bị tạo lại khi tải xong',
      );
      expect(find.byKey(const ValueKey('video-loading')), findsNothing);
      expect(find.text(S.videoLoading), findsNothing);
      expect(find.byKey(const ValueKey('fake-player')), findsOneWidget);

      video.fail();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('video-failed')), findsOneWidget);
      expect(find.text(S.videoLoadFailed), findsOneWidget);
      expect(find.text(e.nameVi), findsOneWidget, reason: 'F19-R2');
      await tapKey(tester, 'video-retry');
      expect(video.opened, hasLength(2));
      expect(video.closed, 1, reason: 'trình phát cũ được hủy');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('video-loading')),
          matching: find.text(S.videoLoading),
        ),
        findsOneWidget,
      );

      await tapKey(tester, 'exercise-back');
      expect(video.closed, 2);
    });

    testWidgets(
      'F18-E1: video Không khả dụng → khung xám "Video không khả '
      'dụng", không nút phát, không "Thử lại"; tên, hình, hướng dẫn vẫn hiện',
      (tester) async {
        await seedSetUp(db);
        final e = exerciseOf(library, MuscleRegion.deltSide, 'machine');
        await seedLibrary(db, [
          for (final x in library)
            x.id == e.id
                ? x.copyWith(
                    videoAvailable: false,
                    videoUnavailableReason: VideoUnavailableReason.removed,
                  )
                : x,
        ]);
        await pump(tester);
        await openExercise(tester, e);
        expect(find.byKey(const ValueKey('video-unavailable')), findsOneWidget);
        expect(find.text(S.videoUnavailable), findsOneWidget);
        expect(find.byKey(const ValueKey('video-play')), findsNothing);
        expect(find.byKey(const ValueKey('video-retry')), findsNothing);
        expect(find.text(e.nameVi), findsOneWidget);
        expect(find.text(e.guideSteps.first), findsOneWidget);
      },
    );

    testWidgets('F18-AC3, UX-AC37: tắt mạng → S-66, S-67 dùng bình thường, '
        'không vòng xoay; khu video "Cần kết nối internet để xem video.", '
        'không tạo trình phát; có mạng lại → nút phát', (tester) async {
      await seedSetUp(db);
      await seedLibrary(db);
      connectivity.online = false;
      await pump(tester);
      await openLibrary(tester);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final e = exerciseOf(library, MuscleRegion.backMid);
      await tapKey(tester, 'exercise-${e.id}');
      expect(find.byKey(const ValueKey('video-offline')), findsOneWidget);
      expect(find.text(S.videoOffline), findsOneWidget);
      expect(find.text(e.nameVi), findsOneWidget);
      expect(
        find.byKey(const ValueKey('body-map-male_back-back_mid')),
        findsOneWidget,
      );
      expect(find.text(e.guideSteps.first), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(video.opened, isEmpty);

      connectivity.setOnline(true);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('video-play')), findsOneWidget);

      // Mất mạng mà chưa có sự kiện: chạm phát → báo cần mạng, không tải.
      connectivity.online = false;
      await tapKey(tester, 'video-play');
      expect(find.byKey(const ValueKey('video-offline')), findsOneWidget);
      expect(video.opened, isEmpty);
    });

    testWidgets('F10-AC21: nhãn hướng dẫn có ở chi tiết bài; chạm → bảng giải '
        'thích như nhãn "tham khảo" của Bản 1', (tester) async {
      await seedSetUp(db);
      await seedLibrary(db);
      await pump(tester, tall: true);
      await openExercise(tester, exerciseOf(library, MuscleRegion.biceps));
      expect(
        find.text(
          'Hướng dẫn tham khảo cho người khỏe mạnh, không thay huấn luyện '
          'viên.',
        ),
        findsOneWidget,
      );
      await tapKey(tester, 'exercise-guide-note');
      expect(find.byType(DisclaimerPoints), findsOneWidget);
    });

    testWidgets('F19-E2: bài đã rời thư viện mở bằng đường dẫn (buổi cũ, '
        'Tiến bộ) → "Không còn trong thư viện" ngay dưới tên, hướng dẫn và '
        'hình vẫn hiện; nút quay lại theo màn trước', (tester) async {
      await seedSetUp(db);
      final e = exerciseOf(library, MuscleRegion.tricepsLong);
      await seedLibrary(db, [
        for (final x in library) x.id == e.id ? x.copyWith(active: false) : x,
      ]);
      await pump(tester);
      container
          .read(routerProvider)
          .go(exercisePath(e.id, ExerciseFrom.progress));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('not-in-library')), findsOneWidget);
      expect(find.text(S.notInLibrary), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('not-in-library'))).dy,
        greaterThan(tester.getTopLeft(find.text(e.nameVi)).dy),
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('not-in-library'))).dy,
        lessThan(
          tester
              .getTopLeft(
                find.text('${Fmt.muscle(e.group)} · ${Fmt.region(e.region)}'),
              )
              .dy,
        ),
      );
      expect(find.text(e.guideSteps.first), findsOneWidget);
      expect(find.text(S.backProgress), findsOneWidget);
    });
  });

  testWidgets('dữ liệu đổi trong lúc S-67 che thư viện (đồng bộ kéo về buổi '
      'hôm nay) → quay lại không lỗi, thư viện cập nhật', (tester) async {
    await seedSetUp(db);
    await seedLibrary(db);
    await pump(tester);
    await openLibrary(tester);
    final e = exerciseOf(library, MuscleRegion.lats, 'machine');
    await tapKey(tester, 'exercise-${e.id}');
    // Buổi hôm nay được đánh dấu trên máy khác, kéo về khi S-67 đang mở:
    // các provider của màn bị che đang tạm dừng.
    final schedule = ScheduleRepository(db);
    final today = (await schedule.day(LocalDate(2026, 10, 14)))!;
    await schedule.putDay(
      today.withMark(DayMark.skipped, markedAt: DateTime(2026, 10, 14, 9, 30)),
    );
    await tester.pumpAndSettle();
    await tapKey(tester, 'exercise-back');
    expect(tester.takeException(), isNull);
    expect(find.byType(LibraryScreen), findsOneWidget);
  });

  testWidgets('dữ liệu đổi khi đang ở tab khác (tab Tập luyện tạm dừng) → '
      'quay lại tab không lỗi', (tester) async {
    await seedSetUp(db);
    await seedLibrary(db);
    await pump(tester);
    await openLibrary(tester);
    await tester.tap(tabBarText(S.tabMe));
    await tester.pumpAndSettle();
    final schedule = ScheduleRepository(db);
    final today = (await schedule.day(LocalDate(2026, 10, 14)))!;
    await schedule.putDay(
      today.withMark(DayMark.skipped, markedAt: DateTime(2026, 10, 14, 9, 30)),
    );
    container.invalidate(nowProvider);
    await tester.pumpAndSettle();
    await tester.tap(tabBarText(S.tabTraining));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await selectSection(tester, 'schedule');
    await tester.tap(tabBarText(S.tabToday));
    await tester.pumpAndSettle();
    await tester.tap(tabBarText(S.tabTraining));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(ScheduleScreen), findsOneWidget);
  });

  testWidgets('UX-AC40, F18-AC6: hồ sơ Nữ → hình thu nhỏ và hình lớn bản nữ; '
      'đổi sang Nam → bản nam ngay', (tester) async {
    await seedSetUp(db);
    await seedLibrary(db);
    final profiles = ProfileRepository(db);
    await profiles.put(completedProfile().copyWith(sex: Sex.female));
    await pump(tester);
    await openLibrary(tester);
    expect(
      find.byKey(const ValueKey('body-map-female_back-lats')),
      findsNWidgets(2),
    );
    expect(find.byKey(const ValueKey('body-map-male_back-lats')), findsNothing);
    final e = exerciseOf(library, MuscleRegion.lats, 'machine');
    await tapKey(tester, 'exercise-${e.id}');
    expect(
      find.byKey(const ValueKey('body-map-female_back-lats')),
      findsOneWidget,
    );

    await profiles.put(completedProfile().copyWith(sex: Sex.male));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('body-map-male_back-lats')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('body-map-female_back-lats')),
      findsNothing,
    );
    await tapKey(tester, 'exercise-back');
    expect(
      find.byKey(const ValueKey('body-map-male_back-lats')),
      findsNWidgets(2),
    );
  });
}
