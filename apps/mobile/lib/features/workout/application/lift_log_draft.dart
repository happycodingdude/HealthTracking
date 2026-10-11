import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ô của bảng ghi mức tạ.
enum LiftField { start, end }

/// Mở S-64 cho bài [exercise] trong buổi ngày [date]: [existing] = bản ghi
/// của buổi (chế độ sửa), [previous] = buổi trước của bài (FR2-06).
typedef LiftDraftArgs = ({
  LocalDate date,
  Exercise exercise,
  LiftLog? existing,
  LiftLog? previous,
});

/// Hai ô số của S-64 (04 Bản 2 S-64, UA2-10, UA2-11): chữ Bạn gõ, lỗi sau
/// khi bấm Lưu, cảnh báo F21-R8 tính ngay khi ô Kết thúc có số hợp lệ.
final class LiftDraft {
  const LiftDraft({this.start = '', this.end = '', this.previous, this.input});

  /// Chữ trong ô, luôn dùng dấu phẩy (UR-10).
  final String start;
  final String end;

  /// Buổi trước của bài; null = lần ghi đầu tiên.
  final LiftLog? previous;

  /// Kết quả kiểm tra lần bấm Lưu gần nhất; null = chưa bấm hoặc đã sửa ô.
  final LiftInput? input;

  String text(LiftField f) => f == LiftField.start ? start : end;

  /// Lỗi hiện dưới hai ô (F21-V1 → V4): lỗi của ô Bắt đầu trước.
  LiftInputError? get error => input?.startError ?? input?.endError;

  /// F21-R8: so mức kết thúc với buổi trước; null khi ô Kết thúc chưa hợp lệ.
  EndWarning? get warning {
    final (endX10, invalid) = LiftKg.check(end);
    if (invalid != null) return null;
    return EndWarning.of(previous?.endKgX10, endX10!);
  }

  /// Nút − / + của ô [f] bấm được: ô đã có số; riêng ô Kết thúc trống thì
  /// lấy mức Bắt đầu làm điểm xuất phát (UA2-10).
  bool canStep(LiftField f) => _base(f) != null;

  int? _base(LiftField f) {
    final (value, _) = LiftKg.parse(text(f));
    if (value != null) return value;
    if (f == LiftField.end && end.trim().isEmpty) {
      return LiftKg.parse(start).$1;
    }
    return null;
  }

  LiftDraft edit(LiftField f, String text) {
    final shown = text.replaceAll('.', ',');
    return LiftDraft(
      start: f == LiftField.start ? shown : start,
      end: f == LiftField.end ? shown : end,
      previous: previous,
    );
  }

  /// Thêm [delta] bước 0,5 kg vào ô [f], chặn ở 0,5 và 300 (F21-V2).
  LiftDraft step(LiftField f, int delta) {
    final base = _base(f);
    if (base == null) return this;
    return edit(f, LiftKg.format(LiftKg.stepped(base, delta)));
  }

  LiftDraft check() => LiftDraft(
    start: start,
    end: end,
    previous: previous,
    input: LiftInput.of(start, end),
  );
}

/// Bản nháp của S-64 (05 Bản 2 §6.4.2 `liftLogDraftProvider`). Chế độ sửa
/// điền sẵn bản ghi đã có; lần đầu cả hai ô trống — không điền mức của buổi
/// trước để app không gợi ý mức tạ (UA2-10, A2-09).
final liftLogDraftProvider = NotifierProvider.autoDispose
    .family<LiftLogDraft, LiftDraft, LiftDraftArgs>(LiftLogDraft.new);

class LiftLogDraft extends Notifier<LiftDraft> {
  LiftLogDraft(this.args);

  final LiftDraftArgs args;

  @override
  LiftDraft build() {
    final existing = args.existing;
    return LiftDraft(
      start: existing == null ? '' : LiftKg.format(existing.startKgX10),
      end: existing == null ? '' : LiftKg.format(existing.endKgX10),
      previous: args.previous,
    );
  }

  void edit(LiftField f, String text) => state = state.edit(f, text);

  void step(LiftField f, int delta) => state = state.step(f, delta);

  /// Kiểm tra F21-V1 → V4 khi bấm Lưu; true = hợp lệ.
  bool check() {
    state = state.check();
    return state.input!.isValid;
  }
}
