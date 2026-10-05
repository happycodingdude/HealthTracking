import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/heading.dart';
import '../../../core/widgets/reference_tag.dart';

/// S-55 — Về gợi ý tham khảo: nội dung giống S-02, không có nút "Tôi đã hiểu"
/// (F10-R4). Mở được cả trong lúc thiết lập lần đầu (từ nhãn "tham khảo").
class AboutReferenceScreen extends StatelessWidget {
  const AboutReferenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.only(right: 12),
                ),
                onPressed: () => context.pop(),
                icon: const Icon(Icons.chevron_left),
                label: const Text(S.back),
              ),
            ),
            const SizedBox(height: 16),
            Heading(
              S.disclaimerTitle,
              style: context.text.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            const DisclaimerPoints(),
          ],
        ),
      ),
    );
  }
}
