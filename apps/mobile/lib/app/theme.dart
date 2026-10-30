import 'package:flutter/material.dart';

import '../ui/theme.dart';

export '../ui/theme.dart';

/// Lớp tương thích tạm trong Phase 7 Bản 4: màn hình chưa viết lại vẫn đọc
/// `context.palette` / `context.colors`; giá trị ánh xạ từ token tối. Mỗi
/// slice viết lại màn sẽ bỏ dần; VS-51 xóa file này (TD4-04: không giữ hai bộ).
@immutable
class AppPalette {
  const AppPalette();

  Color get textSecondary => TokenColor.textSecondary;
  Color get border => TokenColor.divider;
  Color get card => TokenColor.surface;
  Color get success => TokenColor.accent;
  Color get successContainer => TokenColor.accentSoft;
  Color get attention => TokenColor.accent;
  Color get attentionContainer => TokenColor.accentSoft;
  Color get neutral => TokenColor.textSecondary;
  Color get neutralContainer => TokenColor.surfaceRaised;
  Color get reference => TokenColor.accent;
  Color get referenceContainer => TokenColor.surfaceRaised;
  Color get scrim => TokenColor.scrim;
}

extension AppThemeX on BuildContext {
  AppPalette get palette => const AppPalette();
  ColorScheme get colors => Theme.of(this).colorScheme;
}

/// Theme của app: chỉ còn một theme tối (TD4-03).
abstract final class AppTheme {
  static ThemeData dark() => IronlyTheme.dark();
}
