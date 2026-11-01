import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ô của bảng ghi mức tạ.
enum LiftField { start, end }

/// Mở S-64 cho bài [exercise] trong buổi ngày [date]: [existing] = bản ghi
/// của buổi (chế độ sửa), [previous] = buổi trước của bài (FA3-01), [unit] =
/// đơn vị hiện tại của bài, null khi chưa từng ghi (F21-R41); [note] = ghi
/// chú của buổi, [previousNote] = ghi chú buổi trước (FA3-02).
typedef LiftDraftArgs = ({
  LocalDate date,
  Exercise exercise,
  LiftLog? existing,
  LiftLog? previous,
  LiftUnit? unit,
  ExerciseNote? note,
  ExerciseNote? previousNote,
});

/// Bảng ghi tạ S-64 (04 Bản 3 §6.6, 05 Bản 3 §6.4.2 `liftLogDraftProvider`):
/// hai ô (điền sẵn xám / đã sửa), đơn vị, lỗi sau khi bấm Lưu, cảnh báo
/// F21-R45 (chỉ khi ô Kết thúc đã sửa, FA3-07), ghi chú, [isDirty] (ED3-12).
final class LiftDraft {
  const LiftDraft({
    required this.args,
    required this.unit,
    required this.start,
    required this.end,
    required this.note,
    this.startEdited = false,
    this.endEdited = false,
    this.stepped = false,
    this.input,
  });

  factory LiftDraft.open(LiftDraftArgs args) {
    final (:startX10, :endX10, fromPrevious: _) = LiftPrefill.of(
      today: args.existing,
      previous: args.previous,
    );
    String text(int? x10) => x10 == null ? '' : LiftKg.format(x10);
    return LiftDraft(
      args: args,
      unit: args.unit,
      start: text(startX10),
      end: text(endX10),
      note: args.note?.text ?? '',
    );
  }

  final LiftDraftArgs args;

  /// Đơn vị của bài, hoặc đơn vị Bạn vừa chọn ở lần ghi đầu; null = chưa
  /// chọn (F21-V41).
  final LiftUnit? unit;

  /// Chữ trong ô, luôn dùng dấu phẩy (UR-10).
  final String start;
  final String end;
  final String note;

  /// Ô đã được Bạn sửa (gõ hoặc bấm ±bước): số chuyển màu thường (UA3-06).
  final bool startEdited;
  final bool endEdited;

  /// Đã bấm ±bước, kể cả khi số không đổi (UA3-03).
  final bool stepped;

  /// Kết quả kiểm tra lần bấm Lưu gần nhất; null = chưa bấm hoặc đã sửa.
  final LiftInput? input;

  /// Bài bụng: chỉ có ô ghi chú (S-64-4, UA3-08).
  bool get noteOnly => !args.exercise.logsWeight;

  /// Lần ghi đầu: hiện thanh chọn kg | nấc máy (UA3-09).
  bool get choosingUnit => !noteOnly && args.unit == null;

  /// Hai ô là mức buổi trước (chưa có bản ghi hôm nay).
  bool get prefilled => args.existing == null && args.previous != null;

  String text(LiftField f) => f == LiftField.start ? start : end;

  bool edited(LiftField f) => f == LiftField.start ? startEdited : endEdited;

  /// Số còn là gợi ý (màu xám, UA3-06).
  bool isGray(LiftField f) => prefilled && !edited(f);

  bool get bothEmpty => start.trim().isEmpty && end.trim().isEmpty;

  /// Lỗi sau khi bấm Lưu: thiếu đơn vị (dưới thanh chọn) hoặc lỗi ô số.
  LiftInputError? get error => input?.error;

  /// Ghi chú khác lúc mở bảng.
  bool get noteChanged =>
      ExerciseNoteRules.normalize(note) !=
      ExerciseNoteRules.normalize(args.note?.text ?? '');

  /// UA3-03, ED3-12: số khác lúc mở, ghi chú khác lúc mở, hoặc đã bấm ±bước.
  bool get isDirty {
    final initial = LiftDraft.open(args);
    return stepped ||
        start != initial.start ||
        end != initial.end ||
        note != initial.note;
  }

  /// F21-R45: so mức kết thúc với buổi trước khi ô Kết thúc có số hợp lệ và
  /// đã sửa (FA3-07); null khi không cảnh báo.
  EndWarning? get warning {
    final u = unit;
    if (u == null || noteOnly) return null;
    final (endX10, invalid) = LiftKg.check(end, u);
    if (invalid != null) return null;
    return EndWarning.of(
      args.previous?.endKgX10,
      endX10!,
      u,
      edited: endEdited,
    );
  }

  LiftDraft _copy({
    LiftUnit? unit,
    String? start,
    String? end,
    String? note,
    bool? startEdited,
    bool? endEdited,
    bool? stepped,
  }) => LiftDraft(
    args: args,
    unit: unit ?? this.unit,
    start: start ?? this.start,
    end: end ?? this.end,
    note: note ?? this.note,
    startEdited: startEdited ?? this.startEdited,
    endEdited: endEdited ?? this.endEdited,
    stepped: stepped ?? this.stepped,
  );

  LiftDraft edit(LiftField f, String text) {
    final shown = text.replaceAll('.', ',');
    if (shown == this.text(f)) return this;
    return f == LiftField.start
        ? _copy(start: shown, startEdited: true)
        : _copy(end: shown, endEdited: true);
  }

  /// Nút −bước / +bước (F21-R43): chưa chọn đơn vị → không tác dụng; ra
  /// ngoài khoảng → giữ nguyên (F21-E44, E45). Đã chọn đơn vị mà ô trống
  /// thì vẫn bấm được (Bạn quyết 31/10/2026, thay FA3-05): ±bước từ số của ô
  /// còn lại; ô còn lại cũng trống → một bước (2,5 kg / 1 nấc).
  LiftDraft step(LiftField f, int delta) {
    final u = unit;
    final (value, _) = LiftKg.parse(text(f));
    final int? next;
    if (u == null) {
      next = null;
    } else if (text(f).trim().isEmpty) {
      final other = f == LiftField.start ? end : start;
      final (base, _) = LiftKg.parse(other);
      next = base == null ? LiftStep.of(u) : LiftStep.apply(base, delta, u);
    } else {
      next = LiftStep.apply(value, delta, u);
    }
    final changed = next != null && next != value;
    final shown = changed ? LiftKg.format(next) : text(f);
    return f == LiftField.start
        ? _copy(
            start: shown,
            startEdited: startEdited || changed,
            stepped: true,
          )
        : _copy(end: shown, endEdited: endEdited || changed, stepped: true);
  }

  LiftDraft chooseUnit(LiftUnit unit) => _copy(unit: unit);

  /// F26-V1, E1: không quá 200 ký tự.
  LiftDraft editNote(String text) => _copy(note: ExerciseNoteRules.clip(text));

  /// Kiểm tra khi bấm Lưu (F21-V41 → V45). Hai ô trống thì chỉ lưu ghi chú
  /// (F21-R49) nên không kiểm số; riêng lần ghi đầu chưa chọn đơn vị và chưa
  /// có gì để lưu → báo chọn đơn vị (F21-AC43, UX-AC49).
  LiftDraft check() {
    final LiftInput? input;
    if (noteOnly) {
      input = null;
    } else if (bothEmpty) {
      input = choosingUnit && unit == null && !noteChanged
          ? LiftInput.of('', '', null)
          : null;
    } else {
      input = LiftInput.of(start, end, unit);
    }
    return LiftDraft(
      args: args,
      unit: unit,
      start: start,
      end: end,
      note: note,
      startEdited: startEdited,
      endEdited: endEdited,
      stepped: stepped,
      input: input,
    );
  }
}

final liftLogDraftProvider = NotifierProvider.autoDispose
    .family<LiftLogDraft, LiftDraft, LiftDraftArgs>(LiftLogDraft.new);

class LiftLogDraft extends Notifier<LiftDraft> {
  LiftLogDraft(this.args);

  final LiftDraftArgs args;

  @override
  LiftDraft build() => LiftDraft.open(args);

  void edit(LiftField f, String text) => state = state.edit(f, text);

  void step(LiftField f, int delta) => state = state.step(f, delta);

  void chooseUnit(LiftUnit unit) => state = state.chooseUnit(unit);

  void editNote(String text) => state = state.editNote(text);

  /// Kiểm tra F21-V41 → V45 khi bấm Lưu; true = lưu được.
  bool check() {
    state = state.check();
    return state.input?.isValid ?? true;
  }
}
