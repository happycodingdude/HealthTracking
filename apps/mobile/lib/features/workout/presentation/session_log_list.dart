import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/app_tab.dart';
import '../../../app/strings_vi.dart';
import '../../../app/time_ticker.dart';
import '../../../core/formatters.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
import '../../library/presentation/body_map.dart';
import '../application/session_providers.dart';
import 'exercise_actions_sheet.dart';
import 'lift_log_sheet.dart';
import 'pick_exercise_screen.dart';
import 'session_screen.dart';

/// Danh sách bài của buổi ngày [date] với hàng số mức tạ ngay trong danh sách
/// (04 Bản 4 S-10 H3 → H6, S-63; 05 Bản 4 TD4-05 `SessionLogList`). Dùng
/// chung cho Hôm nay (buổi hôm nay) và Buổi tập ngày khác. Buổi nhiều nhóm:
/// chia tiêu đề nhóm in hoa nhỏ; buổi một nhóm: không tiêu đề.
class SessionLogList extends ConsumerWidget {
  const SessionLogList({super.key, required this.date, required this.tab});

  final LocalDate date;

  /// Tab chứa danh sách (đường dẫn S-67).
  final AppTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider(date));
    final exercises = ref.watch(sessionExercisesProvider(date));
    // Giữ sẵn mọi bản ghi để S-64 có "Buổi trước" ngay khi mở.
    ref.watch(allLiftLogsProvider);
    if (session == null || exercises == null) return const SizedBox.shrink();
    final multi = exercises.groups.length > 1;
    // ··· → S-74 chỉ ở buổi theo lịch hôm nay trên Hôm nay (04 Bản 5 S-10,
    // UA5-01); buổi tập thêm hôm nay giữ ··· → S-67 (F28-R9); buổi ngày khác
    // (S-63) không có ···.
    final today = LocalDate.fromDateTime(ref.watch(nowProvider));
    final more = tab != AppTab.today || date != today
        ? LiftRowMore.none
        : session.isExtra
        ? LiftRowMore.exercise
        : LiftRowMore.actions;
    return Column(
      key: const ValueKey('session-log-list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // "+ Thêm bài" (04 Bản 5 S-10, UD5-05): chỉ buổi theo lịch hôm nay
        // trên Hôm nay (không có ở ngày nghỉ, Buổi tập thêm, S-63); mờ khi
        // buổi "Đã tập" (BR5-13, F30-R7). Đầu danh sách (Bạn yêu cầu
        // 06/11/2026: cuối danh sách dài khó thấy).
        if (more == LiftRowMore.actions) ...[
          AddRow(
            key: const ValueKey('add-exercise'),
            label: S.addExerciseRow,
            onTap: ref.watch(sessionActionsProvider(date)) == null
                ? () => context.push(pickExercisePath(date))
                : null,
          ),
          const SizedBox(height: TokenSpace.s4),
        ],
        for (final (gi, g) in exercises.groups.indexed) ...[
          if (multi)
            Padding(
              padding: EdgeInsets.only(
                top: gi == 0 ? 0 : TokenSpace.s3,
                bottom: TokenSpace.s2,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  Fmt.muscle(g.group).toUpperCase(),
                  key: ValueKey('session-group-${g.group.name}'),
                  style: IronlyText.groupLabel,
                ),
              ),
            ),
          for (final item in g.items)
            LiftRow(session: session, item: item, tab: tab, more: more),
        ],
        // Bài thêm nối cuối danh sách (A5-02).
        for (final item in exercises.extras)
          LiftRow(session: session, item: item, tab: tab, more: more),
      ],
    );
  }
}

/// Nút ··· cạnh tên bài: S-74 (buổi theo lịch hôm nay, Bản 5), S-67 (buổi
/// tập thêm hôm nay, như Bản 4), không có (S-63, 04 Bản 5).
enum LiftRowMore { actions, exercise, none }

/// Một bài trong danh sách (04 Bản 4 S-10, 04 Bản 5 S-10 / S-63): icon tròn
/// (viền cam khi đã ghi hôm nay) · [⇄ bài thay] tên bài cam · icon ghi chú ·
/// "…" → S-74 / S-67 ([more]); bài thay có dòng mờ "thay {tên gốc}" dưới tên
/// (04 Bản 5 §6.2, UD5-02); hàng nhãn BUỔI TRƯỚC /
/// GẦN NHẤT · BẮT ĐẦU · KẾT THÚC (· ô tick trong cửa sổ ghi); hàng số: ô đầu
/// mức buổi trước (mờ) hoặc ngày gần nhất, hai số trắng 600 khi đã ghi, mờ
/// khi điền sẵn, "—" khi chưa có; ghi chú hôm nay (trắng 12) hoặc buổi trước
/// (mờ 11) ngay dưới hàng. Chạm hàng số → S-64 khi ghi được. Bài bụng: không
/// hàng số, chỉ ghi chú.
///
/// Mức thoải mái (04 Bản 5 §6.2, F20-R62, F33-R5): dấu ba vạch cam ngay sau
/// tên (cách 6) khi buổi này đã chọn mức (S-10 và S-63 ngày đã qua); chưa ghi
/// mức tạ của buổi này thì dấu ba vạch xám ngay sau số ở ô BUỔI TRƯỚC /
/// GẦN NHẤT = mức thoải mái buổi trước (FC5-07), trống thì không dấu.
class LiftRow extends StatelessWidget {
  const LiftRow({
    super.key,
    required this.session,
    required this.item,
    required this.tab,
    this.more = LiftRowMore.exercise,
  });

  final SessionView session;
  final SessionExercise item;
  final AppTab tab;
  final LiftRowMore more;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final e = item.exercise;
    final unit = item.unit ?? LiftUnit.kg;
    final window = session.window;
    // H6 — buổi đã chốt "Không tập": danh sách chỉ xem (03 Bản 4 §6.3).
    final skipped = switch (session.status?.state) {
      SessionState.skipped || SessionState.autoSkipped => true,
      _ => false,
    };
    final open = window.isOpen && !skipped;
    final future = window is LiftWindowNotOpen;
    final prev = item.previous;
    final log = item.log;
    final loggedThisSession = log != null;
    // Bài bỏ qua hôm nay (F-29, 04 Bản 5 §6.2): vẫn hiện đủ hàng số, ghi chú
    // nhưng mờ (Bạn yêu cầu 06/11/2026), không ô tick, không mở bảng ghi tạ
    // (F21-R63).
    final skippedItem = item.item.skipped;
    final isExtraItem = item.item.role == SessionExerciseRole.extra;
    // Nhãn VoiceOver của dấu bài thêm / bài bỏ qua (04 Bản 5 §6.9).
    const extraLabel = S.extraMark;
    const skippedLabel = S.skippedMark;
    final canOpenSheet = open && (e.active || log != null) && !skippedItem;
    final today = session.date == LocalDate.fromDateTime(DateTime.now());

    void openSheet() =>
        showLiftLogSheet(context, date: session.date, exercise: e);
    void openExercise() => context.push(
      today && tab == AppTab.today
          ? todayExercisePath(e.id, session.date)
          : sessionExercisePath(tab, session.date, e.id),
    );
    // Hàng tên bài: S-74 (Xem bài tốn thêm một chạm, UA5-01) hoặc S-67.
    void openMore() => more == LiftRowMore.actions
        ? openExerciseActions(context, date: session.date, entry: item)
        : openExercise();
    final replaced = item.item.role == SessionExerciseRole.replacement
        ? item.item.replaces
        : null;
    // Mức thoải mái của buổi này: dấu cam sau tên (04 Bản 5 §6.2); bài bỏ
    // qua không có (F33-R4).
    final todayFeel = skippedItem ? null : item.feel?.feel;

    // Hàng số (chỉ bài có mức tạ).
    Widget? numbers;
    String? numbersSemantics;
    Widget? previousFeelGlyph;
    if (e.logsWeight) {
      final firstLabel = future ? S.liftLatestLabel : S.liftPreviousLabel;
      final String first;
      final String start;
      final String end;
      final bool strong;
      final stepsSuffix = unit == LiftUnit.steps ? ' ${S.unitSteps}' : '';
      String n(int x10) => Fmt.kgNumber(x10);
      // Dấu mức thoải mái buổi trước sau số ô đầu (chưa ghi buổi này).
      final prevFeel = log == null && prev != null
          ? item.previousFeel?.feel
          : null;
      if (prevFeel != null) {
        previousFeelGlyph = FeelGlyph(
          prevFeel,
          key: ValueKey('feel-previous-${e.id}'),
          previous: true,
        );
      }
      if (future) {
        first = prev == null ? '—' : Fmt.dayMonth(prev.date);
        start = prev == null ? '—' : n(prev.startKgX10);
        end = prev == null ? '—' : n(prev.endKgX10);
        strong = false;
      } else {
        first = prev == null
            ? '—'
            : '${n(prev.startKgX10)} → ${n(prev.endKgX10)}$stepsSuffix';
        if (log != null) {
          start = n(log.startKgX10);
          end = n(log.endKgX10);
          strong = true;
        } else if (open && prev != null) {
          start = n(prev.startKgX10);
          end = n(prev.endKgX10);
          strong = false;
        } else {
          start = '—';
          end = '—';
          strong = false;
        }
      }
      final style = strong ? IronlyText.liftNumber : IronlyText.liftPrefill;
      final tick = open && !skippedItem
          ? Container(
              key: ValueKey('lift-tick-${e.id}'),
              width: TokenSize.check,
              height: TokenSize.check,
              decoration: BoxDecoration(
                color: loggedThisSession ? t.accent : null,
                borderRadius: BorderRadius.circular(TokenRadius.check),
                border: loggedThisSession
                    ? null
                    : Border.all(
                        color: t.textFaint,
                        width: TokenSize.fieldStroke,
                      ),
              ),
              child: loggedThisSession
                  ? Icon(Icons.check, size: 15, color: t.onAccent)
                  : null,
            )
          : null;
      numbersSemantics =
          '$firstLabel $first'
          '${prevFeel == null ? '' : ' ${FeelGlyph.labelOf(prevFeel, previous: true)}'}'
          ', ${S.liftStart} $start, ${S.liftEnd} $end '
          '${Fmt.liftUnit(unit)}'
          '${loggedThisSession ? ', ${S.statLogged}' : ''}';
      numbers = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TokenSpace.s2,
              TokenSpace.s2,
              TokenSpace.s2,
              TokenSpace.s1,
            ),
            child: _Cells(
              first: Text(firstLabel, style: IronlyText.columnLabel),
              start: Text(
                S.liftStart.toUpperCase(),
                style: IronlyText.columnLabel,
              ),
              end: Text(S.liftEnd.toUpperCase(), style: IronlyText.columnLabel),
              trailingWidth: tick == null ? 0 : TokenSize.check + 8,
            ),
          ),
          Material(
            color: t.surface,
            borderRadius: BorderRadius.circular(TokenRadius.row),
            child: InkWell(
              key: ValueKey('lift-row-${e.id}'),
              borderRadius: BorderRadius.circular(TokenRadius.row),
              onTap: canOpenSheet ? openSheet : null,
              child: Padding(
                padding: const EdgeInsets.all(TokenSize.rowPadding),
                child: _Cells(
                  first: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        first,
                        key: ValueKey('lift-prev-${e.id}'),
                        style: IronlyText.liftPrefill,
                      ),
                      if (previousFeelGlyph != null) ...[
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: previousFeelGlyph,
                        ),
                      ],
                    ],
                  ),
                  start: Text(
                    start,
                    key: ValueKey('lift-start-${e.id}'),
                    style: style,
                  ),
                  end: Text(
                    end,
                    key: ValueKey('lift-end-${e.id}'),
                    style: style,
                  ),
                  trailing: tick,
                  trailingWidth: tick == null ? 0 : TokenSize.check + 8,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Ghi chú: hôm nay (trắng 12) hoặc buổi trước (mờ 11).
    Widget? noteLine;
    final note = item.note;
    final previousNote = item.previousNote;
    if (note != null || previousNote != null) {
      final isToday = note != null;
      noteLine = Material(
        color: t.surface,
        borderRadius: BorderRadius.circular(TokenRadius.row),
        child: InkWell(
          key: ValueKey('note-line-${e.id}'),
          borderRadius: BorderRadius.circular(TokenRadius.row),
          onTap: canOpenSheet ? openSheet : null,
          child: Padding(
            padding: const EdgeInsets.all(TokenSize.rowPadding),
            child: Text(
              isToday
                  ? note.text
                  : S.notePrevious(
                      Fmt.dayMonth(previousNote!.date),
                      previousNote.text,
                    ),
              style: isToday
                  ? IronlyText.caption2
                  : IronlyText.caption.copyWith(color: t.textPrefill),
            ),
          ),
        ),
      );
    }

    final noteIcon = item.noteMark != NoteMark.none || (!e.logsWeight && open)
        ? Semantics(
            container: true,
            button: canOpenSheet,
            label: S.noteShort,
            child: ExcludeSemantics(
              child: GestureDetector(
                key: ValueKey('note-mark-${e.id}-${item.noteMark.name}'),
                behavior: HitTestBehavior.opaque,
                onTap: canOpenSheet ? openSheet : openExercise,
                child: Padding(
                  padding: const EdgeInsets.all(TokenSpace.s2),
                  child: Icon(
                    Icons.sticky_note_2_outlined,
                    size: 18,
                    color: item.noteMark == NoteMark.today
                        ? t.accent
                        : t.textSecondary,
                  ),
                ),
              ),
            ),
          )
        : null;

    final avatar = Opacity(
      // Bài bỏ qua: icon mờ 45 % (04 Bản 5 §6.2).
      opacity: skippedItem ? 0.45 : 1,
      child: ExerciseAvatar(
        id: e.id,
        // Viền cam khi buổi này đã ghi: trong cửa sổ (S-10) và buổi đã qua
        // (S-63 Bản 5 "đủ loại dòng như S-10 H4", mock s63).
        ring:
            loggedThisSession &&
            !skippedItem &&
            (open || window is LiftWindowClosed),
        dim: !e.active,
        child: ExcludeSemantics(
          child: BodyMap(region: e.region, size: BodyMap.avatar, bare: true),
        ),
      ),
    );

    return Padding(
      key: ValueKey('lift-block-${e.id}'),
      padding: const EdgeInsets.only(bottom: TokenSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            button: true,
            label: [
              e.nameVi,
              if (replaced != null) S.replacementFor(replaced.nameVi),
              if (isExtraItem) extraLabel,
              if (skippedItem) skippedLabel,
              if (todayFeel != null) FeelGlyph.labelOf(todayFeel),
            ].join(', '),
            child: ExcludeSemantics(
              child: InkWell(
                key: ValueKey('exercise-${e.id}'),
                borderRadius: BorderRadius.circular(TokenRadius.row),
                onTap: openMore,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: TokenSpace.s1),
                  child: Row(
                    children: [
                      avatar,
                      const SizedBox(width: TokenSpace.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                if (replaced != null) ...[
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: Icon(
                                      Icons.swap_horiz,
                                      key: ValueKey('replaced-mark-${e.id}'),
                                      size: 14,
                                      color: t.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                if (isExtraItem) ...[
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: Icon(
                                      Icons.add,
                                      key: ValueKey('extra-mark-${e.id}'),
                                      size: 14,
                                      color: t.accent,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Flexible(
                                  child: Text(
                                    e.nameVi,
                                    key: ValueKey('exercise-name-${e.id}'),
                                    style: skippedItem
                                        ? IronlyText.exerciseName.copyWith(
                                            color: t.textSecondary,
                                            decoration:
                                                TextDecoration.lineThrough,
                                            decorationColor: t.textSecondary,
                                          )
                                        : IronlyText.exerciseName,
                                  ),
                                ),
                                if (todayFeel != null) ...[
                                  const SizedBox(width: 6),
                                  FeelGlyph(
                                    todayFeel,
                                    key: ValueKey('feel-today-${e.id}'),
                                  ),
                                ],
                              ],
                            ),
                            if (replaced != null)
                              Text(
                                S.replacedFrom(replaced.nameVi),
                                key: ValueKey('replaced-from-${e.id}'),
                                style: IronlyText.caption.copyWith(
                                  color: t.textPrefill,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (noteIcon != null) noteIcon,
                      // Bài bỏ qua: vòng gạch ngang ở chỗ ô tick (cùng dấu
                      // "Không tập", 04 Bản 5 §6.2).
                      if (skippedItem)
                        Padding(
                          padding: const EdgeInsets.only(left: TokenSpace.s2),
                          child: StatusGlyph(
                            GlyphStatus.skipped,
                            key: ValueKey('skipped-mark-${e.id}'),
                            label: S.skippedMark,
                            size: 22,
                          ),
                        ),
                      if (more != LiftRowMore.none)
                        Padding(
                          padding: const EdgeInsets.only(left: TokenSpace.s1),
                          child: Icon(
                            Icons.more_horiz,
                            key: ValueKey('more-${e.id}'),
                            size: 18,
                            color: t.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (numbers != null)
            Semantics(
              container: true,
              button: canOpenSheet,
              label: numbersSemantics,
              child: ExcludeSemantics(child: _dimIf(skippedItem, numbers)),
            ),
          if (noteLine != null) ...[
            const SizedBox(height: TokenSpace.s1 + 2),
            _dimIf(skippedItem, noteLine),
          ],
        ],
      ),
    );
  }
}

/// Bài bỏ qua: hàng số, ghi chú mờ 45 % như icon bài.
Widget _dimIf(bool dim, Widget child) =>
    dim ? Opacity(opacity: 0.45, child: child) : child;

/// Ba cột của hàng số: buổi trước / gần nhất (rộng hơn) · bắt đầu · kết thúc
/// · phần phải (ô tick) có bề rộng cố định. Mỗi ô thu nhỏ chữ khi không đủ
/// chỗ (cỡ chữ lớn nhất) thay vì tràn.
class _Cells extends StatelessWidget {
  const _Cells({
    required this.first,
    required this.start,
    required this.end,
    this.trailing,
    this.trailingWidth = 0,
  });

  final Widget first;
  final Widget start;
  final Widget end;
  final Widget? trailing;
  final double trailingWidth;

  @override
  Widget build(BuildContext context) {
    Widget cell(Widget w, int flex) => Expanded(
      flex: flex,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: w,
        ),
      ),
    );
    return Row(
      children: [
        cell(first, 5),
        cell(start, 3),
        cell(end, 3),
        if (trailingWidth > 0)
          SizedBox(
            width: trailingWidth,
            child: Align(alignment: Alignment.centerRight, child: trailing),
          ),
      ],
    );
  }
}
