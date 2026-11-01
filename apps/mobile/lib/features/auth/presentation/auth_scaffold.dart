import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/components/components.dart';
import '../../../ui/keys.dart';
import '../../../ui/theme.dart';

/// Lề ngang của bộ màn đăng nhập (04 Bản 4 v1.7 §6.1 ngoại lệ cỡ).
const authInset = TokenSpace.s6;

/// Khung chung của S-01a, S-01b style "Thẻ hội viên" (04 Bản 4 v1.7 §6.7):
/// đỉnh 56, nút quay lại (chevron 26, vùng chạm 44, lề trái −10) + tiêu đề
/// 17 / 700 ngay cạnh, không căn giữa; cách 20 là tấm thẻ, cách 28 là các ô
/// nhập (cuộn được, thẻ cuộn lên khi bàn phím mở); phần dưới (nút cam + chữ
/// dẫn) luôn nằm trên bàn phím (04 §6.11).
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.card,
    required this.fields,
    required this.bottom,
    this.scrollController,
  });

  final String title;
  final Widget card;
  final List<Widget> fields;
  final List<Widget> bottom;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final padding = MediaQuery.paddingOf(context);
    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: IronlyTheme.authInputs(
          theme.inputDecorationTheme,
        ),
      ),
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: math.max(56, padding.top)),
            ConstrainedBox(
              // Cao 44; chữ lớn thì hàng cao theo tiêu đề, không cắt chữ.
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                children: [
                  const SizedBox(width: authInset - 10),
                  Semantics(
                    button: true,
                    label: MaterialLocalizations.of(context).backButtonTooltip,
                    child: ExcludeSemantics(
                      child: GestureDetector(
                        key: K.pageBack,
                        behavior: HitTestBehavior.opaque,
                        onTap: () => context.canPop()
                            ? context.pop()
                            : context.go('/welcome'),
                        child: SizedBox.square(
                          dimension: 44,
                          child: Icon(
                            Icons.chevron_left,
                            size: 26,
                            color: t.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: TokenSpace.s2),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: IronlyText.authTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: authInset),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(
                  authInset,
                  20,
                  authInset,
                  authInset,
                ),
                children: [card, const SizedBox(height: 28), ...fields],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                authInset,
                TokenSpace.s2,
                authInset,
                math.max(padding.bottom, TokenSpace.s2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
