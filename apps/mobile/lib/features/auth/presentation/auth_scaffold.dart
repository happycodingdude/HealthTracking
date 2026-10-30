import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';

/// Khung chung của S-01a, S-01b (04 Bản 4): tiêu đề giữa + nút quay lại; ô
/// nhập dạng thẻ cuộn được; phần dưới (chữ cam + nút chính) luôn nằm trên bàn
/// phím (04 §6.17).
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.fields,
    required this.bottom,
    this.scrollController,
  });

  final String title;
  final List<Widget> fields;
  final List<Widget> bottom;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return IronlySubPage(
      title: title,
      scrollController: scrollController,
      onBack: () => context.canPop() ? context.pop() : context.go('/welcome'),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: bottom,
      ),
      children: fields,
    );
  }
}

/// Câu báo lỗi không gắn với ô nào (ví dụ không có mạng): banner viền cam, câu
/// giữ nguyên (04 Bản 4 §6.4 bảng trạng thái).
class FormNotice extends StatelessWidget {
  const FormNotice(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TokenSpace.s3),
      child: Semantics(
        liveRegion: true,
        child: IronlyBanner(
          key: const ValueKey('form-notice'),
          text: message,
          icon: Icons.cloud_off_outlined,
        ),
      ),
    );
  }
}
