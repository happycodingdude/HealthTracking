import 'package:flutter/widgets.dart';

/// Bộ `Key` chuẩn của thành phần dùng chung (06 Bản 4 IA4-08): integration
/// test và widget test tìm thành phần bằng `Key`, không bằng chữ hiển thị.
abstract final class K {
  static const tabBar = ValueKey('tab-bar');
  static Key tab(String name) => ValueKey('tab-$name');
  static const tabTodayButton = ValueKey('tab-today-button');
  static Key tabDot(String name) => ValueKey('tab-dot-$name');

  static const pageBack = ValueKey('page-back');
  static const pageTrailing = ValueKey('page-trailing');

  static const sheet = ValueKey('ironly-sheet');
  static const dialog = ValueKey('ironly-dialog');
  static const dialogPrimary = ValueKey('dialog-primary');
  static const dialogSecondary = ValueKey('dialog-secondary');

  static const buttonSpinner = ValueKey('button-spinner');
  static const banner = ValueKey('banner');
  static const bannerAction = ValueKey('banner-action');
  static const toastAction = ValueKey('toast-action');
  static const emptyAction = ValueKey('empty-action');
  static const skeleton = ValueKey('skeleton');

  static Key glyph(String status) => ValueKey('glyph-$status');
  static Key segment(String item) => ValueKey('segment-$item');
  static Key weekCell(String dateKey) => ValueKey('week-cell-$dateKey');
  static Key monthCell(String dateKey) => ValueKey('month-cell-$dateKey');
  static Key progressDot(int index) => ValueKey('progress-dot-$index');
  static Key avatar(String id) => ValueKey('avatar-$id');
  static Key field(String name) => ValueKey('field-$name');
  static Key fieldError(String name) => ValueKey('field-error-$name');
  static Key switchKey(String name) => ValueKey('switch-$name');
}
