import 'package:flutter/material.dart';

import '../keys.dart';
import '../theme.dart';
import 'exercise_avatar.dart';

/// Màn trống chỉ còn icon tròn mờ + nút hành động (03 Bản 4 F4-R7, 04 Bản 4
/// §6.9). Không câu "Chưa có…". [caption] chỉ cho 7 loại chữ phụ còn giữ
/// (ví dụ số lượt AI còn lại).
class EmptyAction extends StatelessWidget {
  const EmptyAction({
    super.key,
    required this.icon,
    this.action,
    this.caption,
    this.inCard = true,
  });

  final IconData icon;
  final Widget? action;
  final String? caption;
  final bool inCard;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final body = Column(
      key: K.emptyAction,
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleIcon(icon, size: 56, color: t.textPrefill),
        if (action != null) ...[const SizedBox(height: TokenSpace.s5), action!],
        if (caption != null) ...[
          const SizedBox(height: TokenSpace.s3),
          Text(caption!, style: IronlyText.caption),
        ],
      ],
    );
    if (!inCard) return Center(child: body);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TokenSpace.s5,
        vertical: 28,
      ),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(TokenRadius.card),
      ),
      child: Center(child: body),
    );
  }
}
