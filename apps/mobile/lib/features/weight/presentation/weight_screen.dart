import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/app_tab.dart';
import '../../../app/strings_vi.dart';
import '../../../core/formatters.dart';
import '../../../data/sync/sync_providers.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
import '../../me/application/calorie_view.dart';
import '../../today/application/today_view.dart';
import 'weight_chart.dart';
import 'weight_sheet.dart';

/// Mọi số cân, cũ → mới.
final weightLogProvider = StreamProvider<WeightLog>(
  (ref) => ref.watch(weightRepositoryProvider).watchAll().map(WeightLog.new),
);

/// S-40 — Cân nặng (04 Bản 4 S-40): thẻ đầu số lớn 36 + "kg" nhỏ, bên phải
/// "↓ 0,4 lần trước", "↓ 2,5 ban đầu", nút cam "Ghi cân" → S-41; thẻ biểu đồ 8
/// tuần; thẻ lịch sử theo tuần, tuần chưa ghi dấu "+" cam. Quy tắc F-07 như
/// Bản 1.
class WeightScreen extends ConsumerWidget {
  const WeightScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(weightLogProvider).value;
    final setup = ref.watch(profileProvider).value?.setupDate;
    final today = ref.watch(todayProvider);
    if (log == null || setup == null) {
      return const IronlyTabPage(tab: AppTab.weight, title: S.tabWeight);
    }
    final weeks = WeightLog.weeks(setupDate: setup, today: today);
    final thisWeek = WeightRules.weekKey(today);
    return IronlyTabPage(
      tab: AppTab.weight,
      title: S.tabWeight,
      children: [
        _Summary(log: log, thisWeek: thisWeek),
        const CardGap(),
        IronlyCard(
          key: const ValueKey('weight-trend'),
          padding: const EdgeInsets.fromLTRB(
            TokenSpace.s3,
            TokenSpace.s4,
            TokenSpace.s2,
            TokenSpace.s2,
          ),
          child: WeightChart(weeks: weeks.reversed.toList(), log: log),
        ),
        const CardGap(),
        _History(weeks: weeks, log: log),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.log, required this.thisWeek});

  final WeightLog log;
  final LocalDate thisWeek;

  /// "0,4" / "0" (không đơn vị, 04 Bản 4 S-40); mũi tên vẽ bằng icon (font
  /// Roboto trên Linux không có ký tự ↓ ↑ — UA-15 giữ cách Bản 1).
  static String magnitude(int diffX10) =>
      diffX10 == 0 ? '0' : Fmt.kgNumber(diffX10.abs());

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final latest = log.latest;
    final previous = log.changeFromPrevious;
    // (chênh, dòng ngắn trên màn, câu đầy đủ cho VoiceOver — F07-R7).
    final changes = [
      if (previous != null) (previous, S.vsPreviousShort, S.vsPrevious),
      if (log.changeFromInitial case final c?)
        (c, S.vsInitialShort, S.vsInitial),
    ];
    // Cỡ chữ lớn (TA4-04): số lớn không bẻ dòng, hai dòng chênh xuống dưới.
    final stacked =
        MediaQuery.textScalerOf(context).scale(1) >= IronlyRow.stackedScale;
    final number = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: Fmt.kgNumber(latest?.kgX10 ?? 0),
            style: IronlyText.numberXL,
          ),
          TextSpan(text: ' ${S.unitKg}', style: IronlyText.caption),
        ],
      ),
      key: const ValueKey('weight-latest'),
      softWrap: false,
      overflow: TextOverflow.visible,
    );
    final deltas = Semantics(
      container: true,
      label: [
        for (final (diff, _, full) in changes) full(Fmt.weightChange(diff)),
      ].join(' · '),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: stacked
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          children: [
            for (final (diff, line, _) in changes)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (diff != 0)
                    Icon(
                      diff < 0 ? Icons.arrow_downward : Icons.arrow_upward,
                      size: TokenType.caption,
                      color: t.textSecondary,
                    ),
                  Text(
                    ' ${line(magnitude(diff))}',
                    style: IronlyText.caption.copyWith(color: t.textSecondary),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
    return IronlyCard(
      key: const ValueKey('weight-summary'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (latest != null) ...[
            if (stacked) ...[
              number,
              const SizedBox(height: TokenSpace.s2),
              deltas,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: number),
                  deltas,
                ],
              ),
            const SizedBox(height: TokenSpace.s4),
          ],
          IronlyButton.primary(
            key: const ValueKey('log-weight'),
            label: S.logWeight,
            onPressed: () => showWeightSheet(context, thisWeek),
          ),
        ],
      ),
    );
  }
}

/// Lịch sử: mới nhất ở trên; "19/10 – 25/10 · 72,4"; tuần chưa ghi: dấu "+"
/// cam → S-41. Chạm dòng → S-41 (sửa).
class _History extends StatelessWidget {
  const _History({required this.weeks, required this.log});

  /// Mới → cũ.
  final List<LocalDate> weeks;
  final WeightLog log;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return IronlyListCard(
      children: [
        for (final week in weeks)
          () {
            final p = log.at(week);
            final range = Fmt.weekRange(week, week.addDays(6));
            if (p == null) {
              return IronlyRow(
                key: ValueKey('weight-week-${week.toKey()}'),
                title: range,
                minHeight: 44,
                titleStyle: IronlyText.body.copyWith(color: t.textSecondary),
                semanticsLabel: '${S.weekLabel(range)}, ${S.notLogged}',
                trailing: Semantics(
                  button: true,
                  label: S.add,
                  child: ExcludeSemantics(
                    child: GestureDetector(
                      key: ValueKey('weight-add-${week.toKey()}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => showWeightSheet(context, week),
                      child: Padding(
                        padding: const EdgeInsets.all(TokenSpace.s1),
                        child: Icon(Icons.add, size: 18, color: t.accent),
                      ),
                    ),
                  ),
                ),
              );
            }
            return IronlyRow(
              key: ValueKey('weight-week-${week.toKey()}'),
              title: range,
              minHeight: 44,
              semanticsLabel: '${S.weekLabel(range)}, ${Fmt.kg(p.kgX10)}',
              trailing: Text(
                Fmt.kgNumber(p.kgX10),
                style: IronlyText.liftNumber,
              ),
              onTap: () => showWeightSheet(context, week, edit: true),
            );
          }(),
      ],
    );
  }
}
