import 'package:flutter/material.dart';

import '../../ui/theme.dart';

/// Chữ dẫn dưới nút của bộ màn đăng nhập (04 Bản 4 v1.7 §6.7): 14 căn giữa,
/// [prefix] chữ phụ ("Đã có thẻ?"), [link] cam 600 ("Đăng nhập"). Cả dòng
/// chạm được, vùng chạm cao 44.
class LinkText extends StatelessWidget {
  const LinkText({
    super.key,
    required this.prefix,
    required this.link,
    required this.onTap,
  });

  final String prefix;
  final String link;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$prefix $link',
    child: ExcludeSemantics(
      child: GestureDetector(
        key: ValueKey('link-$link'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$prefix ', style: IronlyText.authLead),
                TextSpan(text: link, style: IronlyText.authLink),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}
