import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:yaml/yaml.dart';

void main() {
  final spec =
      (loadYaml(File('test/spec_strings.yaml').readAsStringSync()) as YamlMap)
          .cast<String, String>();

  test(
    'UR-12/ED-12: mọi câu trong spec_strings.yaml đúng nguyên văn trong strings_vi.dart',
    () {
      for (final entry in spec.entries) {
        expect(S.catalog[entry.key], entry.value, reason: entry.key);
      }
    },
  );

  test(
    'ED-12: mọi câu hằng trong strings_vi.dart đều có nguồn trong spec_strings.yaml',
    () {
      expect(S.catalog.keys.toSet().difference(spec.keys.toSet()), isEmpty);
    },
  );

  test('UR-14, S-56: câu có tham số', () {
    expect(S.greeting('Minh'), 'Chào Minh');
    expect(S.syncedAt('18:42'), 'Đã đồng bộ lúc 18:42');
  });

  test('OB-1, mock S-03, S-04/S-52, F02-R5: câu có tham số', () {
    expect(S.stepOf(2), 'Bước 2/5');
    expect(S.ageYears(30), '30 tuổi');
    expect(S.belowMaintenance('690'), 'Thấp hơn mức duy trì khoảng 690 kcal');
    expect(
      S.lowCalorieWarning('1.500'),
      'Mức này thấp hơn ngưỡng an toàn tham khảo (1.500 kcal). Thực đơn gợi ý vẫn sẽ dùng tối thiểu 1.500 kcal.',
    );
  });

  test('F03-V2, F03-V3, S-20: câu có tham số', () {
    expect(S.missingTimeFor('Thứ 6'), 'Vui lòng chọn giờ tập cho Thứ 6');
    expect(S.missingMusclesFor('Thứ 6'), 'Vui lòng chọn nhóm cơ cho Thứ 6');
    expect(S.monthTitle(10, 2026), 'Tháng 10/2026');
    expect(S.nextMonthNotice(11), 'Lịch tháng 11 sẽ có từ 01/11');
    expect(S.nextMonthNotice(1), 'Lịch tháng 1 sẽ có từ 01/01');
  });

  test('F04-R3, F04-E1, mock S-06: câu nhắc', () {
    expect(
      S.reminderToday('ngực và tay sau', '18:00'),
      'Hôm nay tập ngực và tay sau lúc 18:00',
    );
    expect(S.reminderTomorrow('bụng', '00:30'), 'Ngày mai tập bụng lúc 00:30');
    expect(
      S.reminderExample('17:00', 'thứ 2'),
      'Ví dụ từ lịch của Bạn: nhắc lúc 17:00 thứ 2. App nhắc 1 giờ trước mỗi buổi theo lịch. Bạn bật hoặc tắt được bất cứ lúc nào ở mục Tôi.',
    );
  });

  test('F08-E2: câu chạm trần ngân sách', () {
    expect(
      S.budgetPaused(11),
      'Gợi ý AI tạm dừng đến ngày 1/11 vì đã dùng hết ngân sách tháng này.',
    );
  });

  test('F05-E1, 04 §6.7.1, UA-08, mock S-23: câu có tham số', () {
    expect(S.markableFrom('18:00'), 'Đánh dấu được từ 18:00');
    expect(
      S.nextSession('Thứ 6', 'Vai', '18:00'),
      'Buổi tới: Thứ 6 · Vai · 18:00',
    );
    expect(S.markedDone('Lưng'), 'Đã ghi: tập Lưng');
    expect(
      S.plannedLine('Ngực và tay sau', '18:00'),
      'Lịch: Ngực và tay sau · 18:00',
    );
  });

  test('F-06, 04 §6.7.3, S-20: câu tiến độ tuần', () {
    expect(S.progressLine(2, 3), 'Đã tập 2/3 buổi theo lịch');
    expect(S.extraCount(1), '+1 buổi thêm');
    expect(S.weekDone(1, 3), 'Đã tập 1/3');
  });

  test('F-07, 04 S-40, S-41: câu cân nặng có tham số', () {
    expect(S.latestWeek('05/10 – 11/10'), 'Mới nhất · Tuần 05/10 – 11/10');
    expect(S.vsPrevious('↓ 0,4 kg'), '↓ 0,4 kg so với lần trước');
    expect(S.vsInitial('↓ 2,5 kg'), '↓ 2,5 kg so với ban đầu');
    expect(S.weightSheetTitle('05/10 – 11/10'), 'Cân nặng tuần 05/10 – 11/10');
    expect(S.weekAlreadyLogged('72,5 kg'), 'Tuần này đã ghi 72,5 kg');
    expect(
      S.replaceWeight('75 kg'),
      'Tuần này đã ghi 75 kg. Thay bằng số mới?',
    );
    expect(
      S.bigWeightChange('8 kg'),
      'Số này chênh 8 kg so với lần trước. Bạn chắc chắn chứ?',
    );
    expect(S.deleteWeightConfirm('05/10'), 'Xóa số cân tuần 05/10?');
    expect(S.weightSaved('72,5 kg'), 'Đã lưu 72,5 kg');
  });

  test('F02-R8, F02-R9, 04 S-50, S-52, S-53: câu mức calo có tham số', () {
    expect(S.profileSummary(175, 30, 'Nam'), '175 cm · 30 tuổi · Nam');
    expect(S.calorieSummary('2.210 kcal', 'Tự động'), '2.210 kcal · Tự động');
    expect(
      S.calorieUpdated('2.210', '2.090'),
      'Mức calo đã cập nhật từ 2.210 thành 2.090 kcal.',
    );
    expect(
      S.calorieProposal('2.090 kcal', byWeight: true),
      'Theo cân nặng mới, mức ước tính là 2.090 kcal. Bạn muốn dùng con số này '
      'không?',
    );
    expect(
      S.calorieProposal('2.090 kcal', byWeight: false),
      'Theo thông tin mới, mức ước tính là 2.090 kcal. Bạn muốn dùng con số '
      'này không?',
    );
    expect(
      S.currentlyUsing('1.900 kcal'),
      'Hiện tại Bạn đang dùng 1.900 kcal.',
    );
    expect(S.useKcal('2.090 kcal'), 'Dùng 2.090 kcal');
    expect(
      S.useAppEstimate('2.090 kcal'),
      'Dùng lại ước tính của app (2.090 kcal)',
    );
  });

  test('F08-R9, 04 S-30, UA-10: câu thực đơn có tham số', () {
    expect(S.remainingToday(3), 'Còn 3 lượt hôm nay');
    expect(S.regenerateWithRemaining(2), 'Gợi ý lại (còn 2 lượt)');
    expect(
      S.regenerateBody(2),
      'Thực đơn hiện tại sẽ được thay bằng thực đơn mới. Còn 2 lượt hôm nay.',
    );
    expect(
      S.menuSafetyFloor('1.500 kcal'),
      'Thực đơn dùng mức an toàn tối thiểu 1.500 kcal.',
    );
    expect(
      S.menuDateLine('Thứ 4, 07/10', '2.090 kcal'),
      'Thứ 4, 07/10 · Theo mức 2.090 kcal',
    );
    expect(
      S.budgetPaused(11),
      'Gợi ý AI tạm dừng đến ngày 1/11 vì đã dùng hết ngân sách tháng này.',
    );
  });
}
