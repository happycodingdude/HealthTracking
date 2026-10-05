import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/heading.dart';

/// Khung chung của S-01a, S-01b: "‹ Quay lại", tiêu đề lớn, nội dung cuộn,
/// phần dưới (liên kết + nút chính) luôn nằm trên bàn phím (04 §6.17).
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.fields,
    required this.bottom,
    this.scrollController,
  });

  final String title;
  final String? subtitle;
  final List<Widget> fields;
  final List<Widget> bottom;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.only(right: 12),
                      ),
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/welcome'),
                      icon: const Icon(Icons.chevron_left),
                      label: const Text(S.back),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Heading(
                    title,
                    style: context.text.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: context.text.bodyLarge?.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  ...fields,
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: bottom,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Câu báo lỗi không gắn với ô nào (ví dụ không có mạng). Màu trung tính: đỏ
/// chỉ dùng cho lỗi nhập liệu (UX-AC17).
class FormNotice extends StatelessWidget {
  const FormNotice(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 20,
              color: context.palette.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                key: const ValueKey('form-notice'),
                style: context.text.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
