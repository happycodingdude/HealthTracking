import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/strings_vi.dart';

/// 06 Bản 3 VS39-T05, VS41-T01: câu chữ của widget và thẻ màn hình khóa viết
/// trong Swift (extension không chạy Dart) phải trùng câu chữ đã chốt trong
/// `strings_vi.dart` (`03` Bản 3 §6.13, `spec_strings.yaml`).
void main() {
  test('S-70: Swift dùng đúng câu chữ của widget', () {
    final swift = File(
      'ios/IronlyWidgets/WidgetContentView.swift',
    ).readAsStringSync();
    for (final text in [
      S.widgetNotDone,
      S.widgetDone,
      S.widgetSkipped,
      S.widgetRest,
      S.widgetOneExtra,
      S.widgetThisWeek,
      S.widgetNoSessionsThisWeek,
      S.widgetNoSchedule,
      S.widgetSignedOut,
    ]) {
      expect(swift, contains('"$text'), reason: text);
    }
    // "Ironly · {Thứ}", "Chưa tập · {giờ}", "{X}/{Y}", "+{n}".
    expect(swift, contains(r'"Ironly · \($0)"'));
    expect(S.widgetHeader('Thứ 3'), 'Ironly · Thứ 3');
    expect(swift, contains(r'"Chưa tập · \($0)"'));
    expect(S.widgetNotDoneAt('18:00'), 'Chưa tập · 18:00');
    expect(swift, contains(r'"\(week.done)/\(week.total) +\(week.extra)"'));
    expect(swift, contains(r'"\(week.done)/\(week.total)"'));
    expect('${S.widgetProgress(2, 4)} ${S.widgetExtra(1)}', '2/4 +1');
  });

  test('S-71: Swift dùng đúng câu chữ của thẻ màn hình khóa', () {
    final swift = File(
      'ios/IronlyWidgets/IronlySessionActivity.swift',
    ).readAsStringSync();
    for (final text in [
      S.activityTitle,
      S.activityLastLogged,
      S.activityNext,
      S.activityNothingLogged,
      S.activityPreviousNone,
      S.activityAllLogged,
      S.activityAbsOnly,
      S.activityNextNone,
    ]) {
      expect(swift, contains('"$text"'), reason: text);
    }
    // "Buổi trước: {a} → {b} {đơn vị}", "Kế tiếp: {a} → {b} {đơn vị}".
    expect(swift, contains(r'"Buổi trước: \($0)"'));
    expect(S.activityPrevious('50 → 55 kg'), 'Buổi trước: 50 → 55 kg');
    expect(swift, contains(r'"Kế tiếp: \($0)"'));
    expect(S.activityNextLift('50 → 55 kg'), 'Kế tiếp: 50 → 55 kg');
  });
}
