import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/shell/app_tab.dart';
import 'package:mobile/ui/components/components.dart';
import 'package:mobile/ui/keys.dart';
import 'package:mobile/ui/theme.dart';

import '../support/golden.dart';

/// 06 Bản 4 VS43-T12: thành phần ở mọi trạng thái; nút mờ không phản ứng
/// (03 Bản 4 F4-R6); glyph có nhãn VoiceOver (TD4-07); theme tối duy nhất.
void main() {
  Widget host(Widget child) =>
      goldenHost(GoldenVariant.normal, Scaffold(body: Center(child: child)));

  testWidgets('F4-R6: nút không làm được thì mờ và chạm không phản ứng', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        IronlyButton.primary(
          label: 'Go',
          onPressed: () => taps++,
          enabled: false,
        ),
      ),
    );
    final opacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byType(IronlyButton),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacity.opacity, IronlyButton.disabledOpacity);
    await tester.tap(find.text('Go'));
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('IronlyButton: loading hiện vòng xoay, không bấm lặp', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        IronlyButton.primary(
          label: 'Go',
          onPressed: () => taps++,
          loading: true,
        ),
      ),
    );
    expect(find.byKey(K.buttonSpinner), findsOneWidget);
    await tester.tap(find.byType(IronlyButton));
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('TD4-07: StatusGlyph đọc nhãn, mỗi trạng thái một key riêng', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        Column(
          children: [
            for (final g in GlyphStatus.values)
              StatusGlyph(g, label: 'label-${g.name}'),
          ],
        ),
      ),
    );
    for (final g in GlyphStatus.values) {
      expect(find.byKey(K.glyph(g.name)), findsOneWidget);
      expect(find.bySemanticsLabel('label-${g.name}'), findsOneWidget);
    }
  });

  testWidgets('StatusGlyph chạm được khi có onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        StatusGlyph(GlyphStatus.markDone, label: 'mark', onTap: () => taps++),
      ),
    );
    await tester.tap(find.byKey(K.glyph('markDone')));
    expect(taps, 1);
  });

  testWidgets('SegmentBar: chọn mục, cho phép chưa chọn', (tester) async {
    String? selected;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) => SegmentBar<String>(
            items: const ['a', 'b'],
            selected: selected,
            label: (i) => i,
            onSelected: (i) => setState(() => selected = i),
          ),
        ),
      ),
    );
    expect(selected, isNull);
    await tester.tap(find.byKey(K.segment('b')));
    await tester.pump();
    expect(selected, 'b');
  });

  testWidgets('IronlySwitch bật / tắt, mờ khi khóa', (tester) async {
    bool? value;
    await tester.pumpWidget(
      host(IronlySwitch(value: false, onChanged: (v) => value = v)),
    );
    await tester.tap(find.byType(IronlySwitch));
    expect(value, isTrue);
    await tester.pumpWidget(
      host(const IronlySwitch(value: true, onChanged: null)),
    );
    expect(
      tester
          .widget<Opacity>(
            find.descendant(
              of: find.byType(IronlySwitch),
              matching: find.byType(Opacity),
            ),
          )
          .opacity,
      0.4,
    );
  });

  testWidgets('IronlyTextField: lỗi hiện câu đỏ dưới ô với key chuẩn', (
    tester,
  ) async {
    final c = TextEditingController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(
        IronlyTextField(
          name: 'phone',
          hint: 'Phone',
          controller: c,
          error: 'Bad',
        ),
      ),
    );
    expect(find.byKey(K.field('phone')), findsOneWidget);
    final error = tester.widget<Text>(find.byKey(K.fieldError('phone')));
    expect(error.style?.color, TokenColor.danger);
  });

  testWidgets('MonthGrid: ô có key theo ngày và nhãn VoiceOver', (
    tester,
  ) async {
    MonthCell? tapped;
    await tester.pumpWidget(
      host(
        MonthGrid(
          weekdayLabels: const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'],
          leading: 2,
          cells: [
            for (var d = 1; d <= 3; d++)
              (
                dateKey: 'd$d',
                day: d,
                kind: MonthCellKind.done,
                extra: false,
                overridden: false,
                semantics: 'day $d',
              ),
          ],
          onTap: (c) => tapped = c,
        ),
      ),
    );
    await tester.tap(find.byKey(K.monthCell('d2')));
    expect(tapped?.day, 2);
    expect(find.bySemanticsLabel('day 3'), findsOneWidget);
  });

  testWidgets('WeekStrip: 6 ô với glyph và nhãn', (tester) async {
    await tester.pumpWidget(
      host(
        WeekStrip(
          days: [
            for (var i = 0; i < 6; i++)
              (
                dateKey: 'w$i',
                label: 'T${i + 2}',
                status: GlyphStatus.rest,
                semantics: 'rest $i',
                highlighted: i == 0,
              ),
          ],
        ),
      ),
    );
    expect(find.byType(StatusGlyph), findsNWidgets(6));
    expect(find.bySemanticsLabel('rest 0'), findsOneWidget);
  });

  testWidgets('IronlyDialog: hai nút ngang, nút phải là hành động chính', (
    tester,
  ) async {
    var primary = 0;
    var secondary = 0;
    await tester.pumpWidget(
      host(
        IronlyDialog(
          title: 'T',
          body: 'B',
          secondaryLabel: 'No',
          onSecondary: () => secondary++,
          primaryLabel: 'Yes',
          onPrimary: () => primary++,
        ),
      ),
    );
    final yes = tester.getCenter(find.byKey(K.dialogPrimary));
    final no = tester.getCenter(find.byKey(K.dialogSecondary));
    expect(yes.dx, greaterThan(no.dx));
    await tester.tap(find.byKey(K.dialogPrimary));
    await tester.tap(find.byKey(K.dialogSecondary));
    expect((primary, secondary), (1, 1));
  });

  testWidgets('SkeletonBox tĩnh trong test, có key', (tester) async {
    await tester.pumpWidget(host(const SkeletonBox(width: 100)));
    await tester.pumpAndSettle();
    expect(find.byKey(K.skeleton), findsOneWidget);
  });

  testWidgets(
    'SpinningIcon: xoay ngược chiều kim đồng hồ 1 vòng/giây; Reduce Motion '
    'thì đứng yên (Bạn yêu cầu 01/11/2026: icon chưa đồng bộ xoay vòng)',
    (tester) async {
      SpinningIcon.animate = true;
      addTearDown(() => SpinningIcon.animate = false);
      const icon = SpinningIcon(Icons.sync, size: 16, color: Colors.grey);
      double turns() => tester
          .widget<RotationTransition>(
            find.descendant(
              of: find.byType(SpinningIcon),
              matching: find.byType(RotationTransition),
            ),
          )
          .turns
          .value;

      await tester.pumpWidget(host(icon));
      expect(turns(), 0);
      await tester.pump(const Duration(milliseconds: 250));
      expect(turns(), moreOrLessEquals(-0.25));
      await tester.pump(const Duration(milliseconds: 500));
      expect(turns(), moreOrLessEquals(-0.75));

      // Giảm chuyển động: dừng ở góc 0, không còn khung hình nào chờ vẽ.
      await tester.pumpWidget(
        host(
          const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: icon,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(turns(), 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('TD4-03: theme tối duy nhất, token qua ThemeExtension', () {
    final theme = IronlyTheme.dark();
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, TokenColor.bg);
    expect(theme.extension<IronlyTokens>(), isNotNull);
    expect(theme.colorScheme.primary, TokenColor.accent);
  });

  testWidgets(
    'Thanh tab: nhãn Hôm nay cùng hàng với 4 nhãn kia (mock 04 Bản 4)',
    (tester) async {
      await tester.pumpWidget(
        goldenHost(
          GoldenVariant.normal,
          Scaffold(
            bottomNavigationBar: IronlyTabBar(
              current: AppTab.schedule,
              onTap: (_) {},
            ),
          ),
        ),
      );
      final tops = {
        for (final tab in AppTab.values)
          tab: tester.getTopLeft(find.text(tab.label)).dy,
      };
      for (final tab in AppTab.values) {
        expect(
          tops[tab],
          moreOrLessEquals(tops[AppTab.schedule]!),
          reason: tab.name,
        );
      }
    },
  );

  testWidgets(
    'IronlyTabPage: nút phải 44 không đẩy tiêu đề và nội dung xuống (mục Lịch ↔ Bài tập)',
    (tester) async {
      Future<(double, double)> layout({required bool withButton}) async {
        await tester.pumpWidget(
          ProviderScope(
            child: goldenHost(
              GoldenVariant.normal,
              IronlyTabPage(
                tab: AppTab.schedule,
                title: 'Tập luyện',
                scrollController: ScrollController(),
                trailing: withButton
                    ? GestureDetector(
                        key: const ValueKey('btn'),
                        onTap: () {},
                        child: const SizedBox(width: 44, height: 44),
                      )
                    : null,
                children: const [SizedBox(key: ValueKey('body'), height: 10)],
              ),
            ),
          ),
        );
        return (
          tester.getTopLeft(find.text('Tập luyện')).dy,
          tester.getTopLeft(find.byKey(const ValueKey('body'))).dy,
        );
      }

      final plain = await layout(withButton: false);
      final button = await layout(withButton: true);
      expect(button.$1, moreOrLessEquals(plain.$1, epsilon: 0.5));
      expect(button.$2, moreOrLessEquals(plain.$2, epsilon: 0.5));
      // Vùng chạm đủ 44 × 44 (04 Bản 1).
      expect(
        tester.getSize(find.byKey(const ValueKey('btn'))),
        const Size(44, 44),
      );
    },
  );
}
