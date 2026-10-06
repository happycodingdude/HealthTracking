import 'package:flutter/material.dart';

/// Màu bổ sung ngoài [ColorScheme] (04 §6.16).
///
/// - Màu chủ đạo xanh ngọc dịu (UA-15).
/// - Đỏ chỉ dùng cho lỗi và nút xóa (UX-AC17): nằm ở `colorScheme.error`.
/// - Vàng cam = cần hành động; xanh lá = đã tập; xám = trung tính.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.textSecondary,
    required this.border,
    required this.card,
    required this.success,
    required this.successContainer,
    required this.attention,
    required this.attentionContainer,
    required this.neutral,
    required this.neutralContainer,
    required this.reference,
    required this.referenceContainer,
    required this.scrim,
  });

  final Color textSecondary;
  final Color border;
  final Color card;

  /// Đã tập.
  final Color success;
  final Color successContainer;

  /// Cần hành động (Chờ đánh dấu, chấm báo hiệu).
  final Color attention;
  final Color attentionContainer;

  /// Trung tính (Không tập, Sắp tới).
  final Color neutral;
  final Color neutralContainer;

  /// Nhãn "tham khảo" (04 §6.13.2): vàng nhạt.
  final Color reference;
  final Color referenceContainer;

  /// Lớp mờ phía sau bảng trượt và hộp thoại (UR-16).
  final Color scrim;

  static const light = AppPalette(
    textSecondary: Color(0xFF56625F),
    border: Color(0xFFD3DBD8),
    card: Color(0xFFFFFFFF),
    success: Color(0xFF2E6B30),
    successContainer: Color(0xFFE2F0E1),
    attention: Color(0xFF8A4B00),
    attentionContainer: Color(0xFFFCEBD5),
    neutral: Color(0xFF5F6967),
    neutralContainer: Color(0xFFECEFEE),
    reference: Color(0xFF7A5200),
    referenceContainer: Color(0xFFFDF1D3),
    scrim: Color(0x66000000),
  );

  static const dark = AppPalette(
    textSecondary: Color(0xFFA5B1AE),
    border: Color(0xFF34403D),
    card: Color(0xFF1A2220),
    success: Color(0xFF8FD18F),
    successContainer: Color(0xFF1E3A1F),
    attention: Color(0xFFFFB86B),
    attentionContainer: Color(0xFF4A3014),
    neutral: Color(0xFFA9B3B0),
    neutralContainer: Color(0xFF2A3331),
    reference: Color(0xFFF4CF7A),
    referenceContainer: Color(0xFF3F3214),
    scrim: Color(0x99000000),
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(AppPalette? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

extension AppThemeX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}

/// Theme sáng và tối theo cài đặt iPhone (UR-05, D-22). Phẳng, viền mảnh,
/// không bóng đổ (04 §6.16).
abstract final class AppTheme {
  static const _tealLight = Color(0xFF0E766C);
  static const _tealDark = Color(0xFF55C5B6);

  static ThemeData light() => _build(
    brightness: Brightness.light,
    palette: AppPalette.light,
    scheme: const ColorScheme(
      brightness: Brightness.light,
      primary: _tealLight,
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFE0F2EF),
      onPrimaryContainer: Color(0xFF00201C),
      secondary: _tealLight,
      onSecondary: Color(0xFFFFFFFF),
      error: Color(0xFFB3261E),
      onError: Color(0xFFFFFFFF),
      surface: Color(0xFFF4F6F5),
      onSurface: Color(0xFF17201E),
      surfaceContainerHighest: Color(0xFFFFFFFF),
      outline: Color(0xFFB9C3C0),
      outlineVariant: Color(0xFFD3DBD8),
    ),
  );

  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    palette: AppPalette.dark,
    scheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: _tealDark,
      onPrimary: Color(0xFF00201C),
      primaryContainer: Color(0xFF12403A),
      onPrimaryContainer: Color(0xFFCDEDE8),
      secondary: _tealDark,
      onSecondary: Color(0xFF00201C),
      error: Color(0xFFF2B8B5),
      onError: Color(0xFF601410),
      surface: Color(0xFF0F1413),
      onSurface: Color(0xFFE5EBE9),
      surfaceContainerHighest: Color(0xFF1A2220),
      outline: Color(0xFF55625F),
      outlineVariant: Color(0xFF34403D),
    ),
  );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required AppPalette palette,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );
    final radius = BorderRadius.circular(16);
    final buttonShape = RoundedRectangleBorder(borderRadius: radius);
    const buttonSize = Size(64, 52);
    final buttonText = base.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      extensions: [palette],
      splashFactory: NoSplash.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: palette.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: palette.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          shape: buttonShape,
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: scheme.primary,
          textStyle: base.textTheme.bodyLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        errorMaxLines: 3,
        helperMaxLines: 3,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.card,
        modalBackgroundColor: palette.card,
        showDragHandle: true,
        dragHandleColor: palette.border,
        elevation: 0,
        modalElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    );
  }
}
