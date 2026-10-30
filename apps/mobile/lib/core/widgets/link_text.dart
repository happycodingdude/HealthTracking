import 'package:flutter/material.dart';

import '../../ui/components/components.dart';

/// Dòng liên kết chữ cam (ví dụ "Đã có tài khoản? Đăng nhập", 04 Bản 4 S-01a).
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
  Widget build(BuildContext context) => IronlyButton.link(
    key: ValueKey('link-${link.hashCode}'),
    label: '$prefix $link',
    onPressed: onTap,
  );
}
