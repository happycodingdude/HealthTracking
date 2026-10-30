import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/strings_vi.dart';

/// 06 Bản 3 VS39-T05, VS41-T01: câu chữ của widget và thẻ màn hình khóa viết
/// trong Swift (extension không chạy Dart) phải trùng câu chữ đã chốt trong
/// `strings_vi.dart` (`03` Bản 3 §6.13, `spec_strings.yaml`). Bản 4 (VS-50,
/// FR4-04, FR4-05): bỏ tên app, "Chưa tập", "Vừa ghi / Kế tiếp" dạng chữ;
/// dấu hiệu thay chữ nhưng `accessibilityLabel` vẫn là câu chữ cũ (TD4-07).
/// Mã Swift không kể chú thích (chú thích vẫn nhắc tới chữ đã bỏ).
String code(String path) => File(
  path,
).readAsLinesSync().map((l) => l.replaceFirst(RegExp(r'//.*$'), '')).join('\n');

void main() {
  test('S-70: Swift dùng đúng câu chữ của widget', () {
    final swift = code('ios/IronlyWidgets/WidgetContentView.swift');
    for (final text in [
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
    // VoiceOver hôm nay chờ đánh dấu: "Chưa tập · {giờ}"; "{X}" + "/{Y}" +
    // " +{n}"; nhãn chấm "Đã tập X/Y buổi theo lịch".
    expect(swift, contains(r'"Chưa tập · \(time)"'));
    expect(S.widgetNotDoneAt('18:00'), 'Chưa tập · 18:00');
    expect(swift, contains(r'"\(week.done)"'));
    expect(swift, contains(r'"/\(week.total)"'));
    expect(swift, contains(r'" +\(week.extra)"'));
    expect('${S.widgetProgress(2, 4)} ${S.widgetExtra(1)}', '2/4 +1');
    expect(
      swift,
      contains(r'"Đã tập \(week.done)/\(week.total) buổi theo lịch"'),
    );
    // FR4-04, FR4-05: không tên app, không chữ "Chưa tập" hiện trên widget.
    expect(swift, isNot(contains('"Ironly')));
    expect(swift, isNot(contains('"Chưa tập"')));
  });

  test('S-71: Swift dùng đúng câu chữ của thẻ màn hình khóa', () {
    final swift = code('ios/IronlyWidgets/IronlySessionActivity.swift');
    for (final text in [
      S.activityLastLogged,
      S.activityNext,
      S.activityNothingLogged,
      S.activityPreviousNone,
      S.activityAllLogged,
      S.activityAbsOnly,
    ]) {
      expect(swift, contains('"$text"'), reason: text);
    }
    // Dynamic Island thu gọn: "→ {a} → {b} {đơn vị}".
    expect(swift, contains(r'"→ \($0)"'));
    // FR4-04, FR4-05: không "Ironly · Buổi tập hôm nay", không "Kế tiếp: …",
    // "Buổi trước: …" dạng chữ (mức buổi trước hiện mờ, không nhãn).
    expect(swift, isNot(contains('"${S.activityTitle}"')));
    expect(swift, isNot(contains(r'"Kế tiếp: \($0)"')));
    expect(swift, isNot(contains(r'"Buổi trước: \($0)"')));
  });
}
