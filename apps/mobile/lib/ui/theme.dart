import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.g.dart';

export 'tokens.g.dart';

/// Token Bản 4 đọc qua `context.tokens` (05 Bản 4 §6.2). Giá trị là hằng
/// sinh từ `design/tokens.json`; `ThemeExtension` để thành phần không phụ
/// thuộc `ColorScheme` của Material.
@immutable
class IronlyTokens extends ThemeExtension<IronlyTokens> {
  const IronlyTokens();

  // Màu (TokenColor).
  Color get bg => TokenColor.bg;
  Color get surface => TokenColor.surface;
  Color get surfaceRaised => TokenColor.surfaceRaised;
  Color get divider => TokenColor.divider;
  Color get textPrimary => TokenColor.textPrimary;
  Color get textSecondary => TokenColor.textSecondary;
  Color get textPrefill => TokenColor.textPrefill;
  Color get textFaint => TokenColor.textFaint;
  Color get accent => TokenColor.accent;
  Color get accentPressed => TokenColor.accentPressed;
  Color get accentSoft => TokenColor.accentSoft;
  Color get onAccent => TokenColor.onAccent;
  Color get danger => TokenColor.danger;
  Color get skipped => TokenColor.skipped;
  Color get locked => TokenColor.locked;
  Color get muscleActive => TokenColor.muscleActive;
  Color get muscleIdle => TokenColor.muscleIdle;
  Color get muscleBody => TokenColor.muscleBody;
  Color get chartLine => TokenColor.chartLine;
  Color get chartGrid => TokenColor.chartGrid;
  Color get scrim => TokenColor.scrim;
  Color get surfaceSunken => TokenColor.surfaceSunken;

  @override
  IronlyTokens copyWith() => this;

  @override
  IronlyTokens lerp(IronlyTokens? other, double t) => this;
}

extension IronlyThemeX on BuildContext {
  IronlyTokens get tokens => Theme.of(this).extension<IronlyTokens>()!;
  TextTheme get text => Theme.of(this).textTheme;
}

/// Kiểu chữ theo vai trò của 04 Bản 4 §6.1 (chữ hệ thống iPhone, số tabular).
abstract final class IronlyText {
  static const _tabular = [FontFeature.tabularFigures()];

  /// Họ chữ của hệ thống theo nền tảng (iPhone: SF qua typography Cupertino
  /// của Flutter; test Linux: Roboto nạp sẵn). Không đặt tên font cứng để
  /// golden và máy thật cùng một cơ chế.
  static String? get family => _family ??= Typography.material2021(
    platform: defaultTargetPlatform,
  ).black.bodyMedium?.fontFamily;
  static String? _family;

  static TextStyle _s(
    double size,
    int weight, {
    Color color = TokenColor.textPrimary,
    double? letterSpacing,
    bool tabular = false,
    double? height,
  }) => TextStyle(
    fontFamily: family,
    fontSize: size,
    fontWeight: FontWeight.values[(weight ~/ 100) - 1],
    color: color,
    letterSpacing: letterSpacing,
    fontFeatures: tabular ? _tabular : null,
    height: height,
  );

  /// Tiêu đề màn 17 / 600.
  static TextStyle get title => _s(TokenType.title, TokenWeight.semibold);

  /// Tiêu đề màn con (giữa) và tên bài trong bảng ghi tạ 15 / 600.
  static TextStyle get subtitle => _s(TokenType.subtitle, TokenWeight.semibold);

  /// Tiêu đề thẻ 13 / 600.
  static TextStyle get cardTitle =>
      _s(TokenType.cardTitle, TokenWeight.semibold);

  /// Dòng chính 14 / 500.
  static TextStyle get body => _s(TokenType.body, TokenWeight.medium);

  /// Dòng chính thường 14 / 400 (đoạn văn).
  static TextStyle get bodyRegular => _s(TokenType.body, TokenWeight.regular);

  /// Tên bài 14 / 600 cam.
  static TextStyle get exerciseName =>
      _s(TokenType.body, TokenWeight.semibold, color: TokenColor.accent);

  /// Dòng phụ 11 / 400 chữ phụ.
  static TextStyle get caption => _s(
    TokenType.caption,
    TokenWeight.regular,
    color: TokenColor.textSecondary,
  );

  /// Chữ phụ 12 (ghi chú hôm nay trắng 12, hộp thoại).
  static TextStyle get caption2 => _s(TokenType.caption2, TokenWeight.regular);

  /// Nhãn cột 9 / 400 in hoa, giãn 0,3.
  static TextStyle get columnLabel => _s(
    TokenType.columnLabel,
    TokenWeight.regular,
    color: TokenColor.textSecondary,
    letterSpacing: 0.3,
  );

  /// Tiêu đề nhóm trong danh sách 11 / 600 in hoa.
  static TextStyle get groupLabel => _s(
    TokenType.groupLabel,
    TokenWeight.semibold,
    color: TokenColor.textSecondary,
    letterSpacing: 0.3,
  );

  /// Số trong hàng ghi tạ 14 / 600 trắng (đã ghi).
  static TextStyle get liftNumber =>
      _s(TokenType.body, TokenWeight.semibold, tabular: true);

  /// Số điền sẵn 14 / 400 mờ.
  static TextStyle get liftPrefill => _s(
    TokenType.body,
    TokenWeight.regular,
    color: TokenColor.textPrefill,
    tabular: true,
  );

  /// Số trong ô của bảng ghi tạ 26 / 600.
  static TextStyle get number =>
      _s(TokenType.number, TokenWeight.semibold, tabular: true);

  /// Số lớn ô ghi cân 30 / 600.
  static TextStyle get numberField =>
      _s(TokenType.numberField, TokenWeight.semibold, tabular: true);

  /// Số lớn 34 / 600 (calo, ngân sách).
  static TextStyle get numberLarge => _s(
    TokenType.numberLarge,
    TokenWeight.semibold,
    tabular: true,
    height: 1.1,
  );

  /// Số lớn 36 / 600 (cân nặng, tiến độ tuần).
  static TextStyle get numberXL =>
      _s(TokenType.numberXL, TokenWeight.semibold, tabular: true, height: 1.1);

  /// Nhãn nút chính / xám 14 / 600.
  static TextStyle get button => _s(TokenType.button, TokenWeight.semibold);

  /// Nhãn nút phụ 14 / 500.
  static TextStyle get buttonSecondary =>
      _s(TokenType.button, TokenWeight.medium);

  /// Nhãn nút xóa 13 / 500 đỏ.
  static TextStyle get buttonDanger =>
      _s(TokenType.buttonSmall, TokenWeight.medium, color: TokenColor.danger);

  /// Nhãn tab 9 / 400.
  static TextStyle get tabLabel => _s(TokenType.tabLabel, TokenWeight.regular);

  /// Câu lỗi 11 / 400 đỏ.
  static TextStyle get error =>
      _s(TokenType.caption, TokenWeight.regular, color: TokenColor.danger);

  /// Tiêu đề hộp xác nhận 15 / 600; câu 13 / 400 chữ phụ.
  static TextStyle get dialogTitle =>
      _s(TokenType.dialogTitle, TokenWeight.semibold);
  static TextStyle get dialogBody => _s(
    TokenType.dialogBody,
    TokenWeight.regular,
    color: TokenColor.textSecondary,
    height: 1.35,
  );

  /// Tên app ở màn Chào mừng 26 / 600.
  static TextStyle get appName => _s(TokenType.appName, TokenWeight.semibold);

  // Bộ màn đăng nhập S-01 → S-01c, style "Thẻ hội viên" (04 Bản 4 v1.7 §6.1
  // ngoại lệ cỡ, §6.7).

  /// "Ironly" góc trên trái S-01: 22 / 800.
  static TextStyle get authAppName =>
      _s(TokenType.authAppName, TokenWeight.heavy);

  /// Tiêu đề màn cạnh nút quay lại, tiêu đề bảng trượt S-01c: 17 / 700.
  static TextStyle get authTitle => _s(TokenType.title, TokenWeight.bold);

  /// Chữ trong ô nhập: 17 / 500.
  static TextStyle get authField =>
      _s(TokenType.authControl, TokenWeight.medium);

  /// Nhãn nút cam: 17 / 700 (màu do nút đặt).
  static TextStyle get authButton =>
      _s(TokenType.authControl, TokenWeight.bold);

  /// Nhãn nút xám: 17 / 600.
  static TextStyle get authButtonGray =>
      _s(TokenType.authControl, TokenWeight.semibold);

  /// Chữ dẫn dưới nút ("Đã có thẻ?"): 14 chữ phụ.
  static TextStyle get authLead =>
      _s(TokenType.body, TokenWeight.regular, color: TokenColor.textSecondary);

  /// Phần liên kết của chữ dẫn, "Quên mật khẩu?": 14 / 600 cam.
  static TextStyle get authLink =>
      _s(TokenType.body, TokenWeight.semibold, color: TokenColor.accent);

  /// Tên trên tấm thẻ hội viên (S-01a), số điện thoại ở S-01b: 26 / 800,
  /// giãn 4.
  static TextStyle get memberName =>
      _s(TokenType.memberName, TokenWeight.heavy, letterSpacing: 4);

  /// "IRONLY" giữa thẻ trước ở S-01: 30 / 800, giãn 5.
  static TextStyle get memberBrand =>
      _s(TokenType.memberBrand, TokenWeight.heavy, letterSpacing: 5);

  /// Số điện thoại dưới tên trên thẻ (S-01a): 14 / 500 chữ phụ, giãn 2.
  static TextStyle get memberPhone => _s(
    TokenType.body,
    TokenWeight.medium,
    color: TokenColor.textSecondary,
    letterSpacing: 2,
  );

  /// "IRONLY" đáy thẻ: 11 / 700 chữ phụ, giãn 3.
  static TextStyle get memberFooter => _s(
    TokenType.caption,
    TokenWeight.bold,
    color: TokenColor.textSecondary,
    letterSpacing: 3,
  );
}

/// Theme tối duy nhất của Bản 4 (TD4-03): không có theme sáng, không rẽ nhánh
/// theo `Brightness`. Mọi màu, cỡ chữ, bo góc từ token.
abstract final class IronlyTheme {
  /// Ô nhập của bộ màn đăng nhập S-01a, S-01b (04 Bản 4 v1.7 §6.1 ngoại lệ
  /// cỡ): cao 54, bo 14, đệm ngang 18, gợi ý trong ô 17 chữ phụ; đang nhập
  /// viền 1,5 cam, lỗi viền 1,5 đỏ.
  static InputDecorationThemeData authInputs(InputDecorationThemeData base) {
    final radius = BorderRadius.circular(TokenRadius.authField);
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: color, width: TokenSize.fieldStroke),
    );
    return base.copyWith(
      hintStyle: IronlyText.authField.copyWith(color: TokenColor.textSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      constraints: const BoxConstraints(minHeight: TokenSize.authField),
      border: border(TokenColor.transparent),
      enabledBorder: border(TokenColor.transparent),
      focusedBorder: border(TokenColor.accent),
      errorBorder: border(TokenColor.danger),
      focusedErrorBorder: border(TokenColor.danger),
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: TokenColor.accent,
      onPrimary: TokenColor.onAccent,
      primaryContainer: TokenColor.accentSoft,
      onPrimaryContainer: TokenColor.accent,
      secondary: TokenColor.accent,
      onSecondary: TokenColor.onAccent,
      error: TokenColor.danger,
      onError: TokenColor.onAccent,
      surface: TokenColor.bg,
      onSurface: TokenColor.textPrimary,
      surfaceContainerHighest: TokenColor.surface,
      surfaceContainer: TokenColor.surface,
      surfaceContainerHigh: TokenColor.surfaceRaised,
      outline: TokenColor.textFaint,
      outlineVariant: TokenColor.divider,
      onSurfaceVariant: TokenColor.textSecondary,
      inversePrimary: TokenColor.accent,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
    );
    final textTheme = base.textTheme.copyWith(
      displayLarge: IronlyText.numberXL,
      displayMedium: IronlyText.numberLarge,
      displaySmall: IronlyText.numberField,
      headlineLarge: IronlyText.number,
      headlineMedium: IronlyText.appName,
      headlineSmall: IronlyText.title,
      titleLarge: IronlyText.title,
      titleMedium: IronlyText.subtitle,
      titleSmall: IronlyText.cardTitle,
      bodyLarge: IronlyText.body,
      bodyMedium: IronlyText.caption2,
      bodySmall: IronlyText.caption,
      labelLarge: IronlyText.button,
      labelMedium: IronlyText.groupLabel,
      labelSmall: IronlyText.columnLabel,
    );
    final radius = BorderRadius.circular(TokenRadius.field);
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: color, width: TokenSize.fieldStroke),
    );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      scaffoldBackgroundColor: TokenColor.bg,
      canvasColor: TokenColor.bg,
      extensions: const [IronlyTokens()],
      splashFactory: NoSplash.splashFactory,
      highlightColor: TokenColor.transparent,
      splashColor: TokenColor.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: ReducedMotionTransitionsBuilder(),
          TargetPlatform.android: ReducedMotionTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: TokenColor.bg,
        foregroundColor: TokenColor.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: IronlyText.subtitle,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: TokenColor.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TokenRadius.card),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TokenColor.surface,
        hintStyle: IronlyText.body.copyWith(color: TokenColor.textPrefill),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: border(TokenColor.transparent),
        enabledBorder: border(TokenColor.transparent),
        focusedBorder: border(TokenColor.accent),
        errorBorder: border(TokenColor.danger),
        focusedErrorBorder: border(TokenColor.danger),
        errorStyle: IronlyText.error,
        errorMaxLines: 3,
        helperMaxLines: 3,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: TokenColor.surface,
        modalBackgroundColor: TokenColor.surface,
        showDragHandle: false,
        elevation: 0,
        modalElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(TokenRadius.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: TokenColor.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TokenRadius.dialog),
        ),
        titleTextStyle: IronlyText.dialogTitle,
        contentTextStyle: IronlyText.dialogBody,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: TokenColor.surfaceRaised,
        contentTextStyle: IronlyText.body.copyWith(
          color: TokenColor.textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TokenRadius.toast),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: TokenColor.divider,
        thickness: TokenSize.dividerStroke,
        space: TokenSize.dividerStroke,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: TokenColor.accent,
        linearTrackColor: TokenColor.surfaceRaised,
      ),
      iconTheme: const IconThemeData(color: TokenColor.textSecondary),
      // Bộ chọn giờ / ngày của iOS cũng tối (TA4-06).
      cupertinoOverrideTheme: const CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: TokenColor.accent,
        scaffoldBackgroundColor: TokenColor.surface,
        barBackgroundColor: TokenColor.surface,
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: TokenColor.surface,
      ),
      timePickerTheme: const TimePickerThemeData(
        backgroundColor: TokenColor.surface,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: TokenColor.accent,
          foregroundColor: TokenColor.onAccent,
          minimumSize: const Size(64, TokenSize.button),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TokenRadius.button),
          ),
          textStyle: IronlyText.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: TokenColor.textPrimary,
          minimumSize: const Size(64, TokenSize.button),
          side: const BorderSide(
            color: TokenColor.surfaceRaised,
            width: TokenSize.fieldStroke,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TokenRadius.button),
          ),
          textStyle: IronlyText.buttonSecondary,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: TokenColor.accent,
          minimumSize: const Size(44, 44),
          textStyle: IronlyText.button,
        ),
      ),
    );
  }
}

/// Chuyển trang kiểu iPhone; bật "Giảm chuyển động" thì đổi trang ngay, không
/// trượt (04 §6.16, 06 VS15-T04).
class ReducedMotionTransitionsBuilder extends PageTransitionsBuilder {
  const ReducedMotionTransitionsBuilder();

  static const _ios = CupertinoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => MediaQuery.disableAnimationsOf(context)
      ? child
      : _ios.buildTransitions(
          route,
          context,
          animation,
          secondaryAnimation,
          child,
        );
}
