import 'package:flutter/material.dart';

import '../keys.dart';
import '../theme.dart';

/// Icon tròn 36 (44 ở tiêu đề màn con): nền thẻ nổi, hình bên trong; viền
/// 1,5 cam khi bài đã ghi hôm nay; mờ khi bài đã rời thư viện (04 Bản 4
/// §6.1, §6.2). [child] là sơ đồ cơ thu nhỏ hoặc icon.
class ExerciseAvatar extends StatelessWidget {
  const ExerciseAvatar({
    super.key,
    this.id,
    required this.child,
    this.size = TokenSize.avatar,
    this.ring = false,
    this.dim = false,
  });

  final String? id;
  final Widget child;
  final double size;
  final bool ring;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Opacity(
      opacity: dim ? 0.4 : 1,
      child: Container(
        key: id == null ? null : K.avatar(id!),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: t.surfaceRaised,
          shape: BoxShape.circle,
          border: ring
              ? Border.all(color: t.accent, width: TokenSize.fieldStroke)
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

/// Icon tròn với icon Material bên trong (mục của tab Tôi, thẻ Nghỉ, màn
/// trống): nét 2 pt chữ phụ.
class CircleIcon extends StatelessWidget {
  const CircleIcon(
    this.icon, {
    super.key,
    this.size = TokenSize.avatar,
    this.color,
    this.ring,
    this.background,
  });

  final IconData icon;
  final double size;
  final Color? color;
  final Color? ring;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? t.surfaceRaised,
        shape: BoxShape.circle,
        border: ring == null
            ? null
            : Border.all(color: ring!, width: TokenSize.fieldStroke),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.5, color: color ?? t.textSecondary),
    );
  }
}
