import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'heading.dart';

/// Thẻ trống dạng lời mời (04 Bản 2 §6.10): tiêu đề, dòng giải thích, và nút
/// chỉ khi có việc Bạn làm được ngay tại đó.
class EmptyCard extends StatelessWidget {
  const EmptyCard({
    super.key,
    required this.title,
    required this.body,
    this.action,
  });

  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Heading(
              title,
              textAlign: TextAlign.center,
              style: context.text.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: context.text.bodyLarge?.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}
