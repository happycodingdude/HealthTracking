import 'package:flutter/material.dart';

import '../../../app/strings_vi.dart';
import '../../../core/widgets/reference_tag.dart';
import '../../../ui/components/components.dart';

/// S-55 — Về gợi ý tham khảo (04 Bản 4 S-55): nội dung 4 ý như S-02, dạng
/// thẻ, không nút (F10-R4). Mở được cả trong lúc thiết lập lần đầu.
class AboutReferenceScreen extends StatelessWidget {
  const AboutReferenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const IronlySubPage(
      title: S.disclaimerTitle,
      children: [DisclaimerPoints()],
    );
  }
}
