import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/strings_vi.dart';

/// 06 Bản 3 VS39-T05: câu chữ của widget viết trong Swift (extension không
/// chạy Dart) phải trùng câu chữ đã chốt trong `strings_vi.dart` (`03` Bản 3
/// §6.13, `spec_strings.yaml`).
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
}
