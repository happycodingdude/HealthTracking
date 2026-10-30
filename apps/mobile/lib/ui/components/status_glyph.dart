import 'package:flutter/material.dart';

import '../keys.dart';
import '../theme.dart';

/// Trạng thái nghiệp vụ thể hiện bằng dấu hiệu, không bằng chữ (03 Bản 4
/// §6.4, 04 Bản 4 §6.2). Hai trạng thái khác nhau không dùng chung dấu.
enum GlyphStatus {
  /// Đã tập: vòng tròn cam đặc, dấu tích trắng.
  done,

  /// Không tập (tự đánh dấu hoặc tự động): vòng thẻ nổi, gạch ngang chữ phụ.
  skipped,

  /// Hôm nay chờ đánh dấu: vòng tròn rỗng viền 2 cam.
  pending,

  /// Sắp tới: vòng tròn thẻ nổi, không ký hiệu.
  upcoming,

  /// Nghỉ: vòng tròn thẻ nổi rỗng (viền).
  rest,

  /// Buổi tập thêm: vòng viền cam, dấu "+" cam.
  extra,

  /// Đã khóa (quá 7 ngày / chỉ xem): ổ khóa chữ phụ.
  locked,

  /// Nút chốt buổi ở góc trên Hôm nay: ô vuông 22 viền cam, dấu tích rỗng.
  markDone,
}

/// Dấu hiệu trạng thái. [label] bắt buộc: VoiceOver đọc đúng câu chữ cũ
/// (05 Bản 4 TD4-07, AP-17); test lint kiểm mọi glyph có nhãn thuộc
/// `spec_strings.yaml`.
class StatusGlyph extends StatelessWidget {
  const StatusGlyph(
    this.status, {
    super.key,
    required this.label,
    this.size = TokenSize.glyph,
    this.onTap,
  });

  final GlyphStatus status;
  final String label;
  final double size;

  /// Chạm dấu (góc trên Hôm nay → S-65 / S-23).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final iconSize = size * 0.64;
    final Widget shape = switch (status) {
      GlyphStatus.done => _circle(
        fill: t.accent,
        child: Icon(Icons.check, size: iconSize, color: t.onAccent),
      ),
      GlyphStatus.skipped => _circle(
        fill: t.surfaceRaised,
        child: Icon(Icons.remove, size: iconSize, color: t.textSecondary),
      ),
      GlyphStatus.pending => _circle(
        border: t.accent,
        borderWidth: TokenSize.ringStroke,
      ),
      GlyphStatus.upcoming => _circle(fill: t.surfaceRaised),
      GlyphStatus.rest => _circle(
        border: t.surfaceRaised,
        borderWidth: TokenSize.fieldStroke,
      ),
      GlyphStatus.extra => _circle(
        border: t.accent,
        borderWidth: TokenSize.fieldStroke,
        child: Icon(Icons.add, size: iconSize, color: t.accent),
      ),
      GlyphStatus.locked => SizedBox.square(
        dimension: size,
        child: Icon(Icons.lock_outline, size: size * 0.8, color: t.locked),
      ),
      GlyphStatus.markDone => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(TokenRadius.check),
          border: Border.all(color: t.accent, width: TokenSize.fieldStroke),
        ),
        child: Icon(Icons.check, size: iconSize, color: t.accent),
      ),
    };
    final body = KeyedSubtree(key: K.glyph(status.name), child: shape);
    if (onTap == null) {
      return Semantics(
        label: label,
        child: ExcludeSemantics(child: body),
      );
    }
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all((44 - size).clamp(0, 44) / 2),
            child: body,
          ),
        ),
      ),
    );
  }

  Widget _circle({
    Color? fill,
    Color? border,
    double borderWidth = 0,
    Widget? child,
  }) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: fill,
      shape: BoxShape.circle,
      border: border == null
          ? null
          : Border.all(color: border, width: borderWidth),
    ),
    alignment: Alignment.center,
    child: child,
  );
}

/// Chấm 4 pt chữ phụ dưới số ngày: ngày sửa riêng khác lịch tuần.
class OverrideDot extends StatelessWidget {
  const OverrideDot({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Container(
      key: K.glyph('overridden'),
      width: TokenSize.dotOverride,
      height: TokenSize.dotOverride,
      decoration: BoxDecoration(
        color: context.tokens.textSecondary,
        shape: BoxShape.circle,
      ),
    ),
  );
}
