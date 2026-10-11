import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/strings_vi.dart';

/// Rà soát toàn app trước khi phát hành Bản 1 (06 VS15-T04 → T06): quét mã
/// nguồn `lib/` và bộ câu chữ.
void main() {
  final sources = {
    for (final f in Directory('lib').listSync(recursive: true))
      if (f is File && f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
        f.path.replaceAll(r'\', '/'): f.readAsStringSync(),
  };

  Set<String> filesUsing(RegExp pattern) => {
    for (final e in sources.entries)
      if (pattern.hasMatch(e.value)) e.key,
  };

  test('UX-AC23: mọi bảng trượt và hộp thoại mở qua app_sheet.dart (có lớp '
      'mờ, trang phía sau giữ nguyên)', () {
    expect(
      filesUsing(
        RegExp(
          r'showModalBottomSheet|showDialog\b|showCupertinoModalPopup|'
          r'showGeneralDialog|showBottomSheet\(',
        ),
      ),
      {'lib/core/widgets/app_sheet.dart'},
    );
  });

  test('UX-AC17: màu đỏ chỉ ở lỗi nhập liệu và nút xóa', () {
    // Mỗi file được duyệt tay: câu lỗi dưới ô/dưới dòng, hoặc nút xóa.
    const reviewed = {
      'lib/app/theme.dart', // định nghĩa colorScheme.error
      'lib/core/widgets/labeled_field.dart', // câu lỗi dưới ô
      'lib/features/onboarding/presentation/profile_fields.dart', // lỗi dưới ô
      'lib/features/onboarding/presentation/schedule_step_screen.dart', // F03-V1
      'lib/features/schedule/presentation/weekly_template_editor.dart', // F03-V2, V3
      'lib/features/schedule/presentation/weekly_schedule_screen.dart', // F03-V1
      'lib/features/schedule/presentation/day_sheet.dart', // F03-V4
      'lib/features/schedule/presentation/extra_session_sheet.dart', // F05-V21
      'lib/features/weight/presentation/weight_sheet.dart', // nút xóa
      // F21-V1 → V4 dưới hai ô, nút "Xóa mức tạ" (UX-AC42).
      'lib/features/workout/presentation/lift_log_sheet.dart',
    };
    final used = filesUsing(
      RegExp(r'colors\.error\b|colorScheme\.error\b|Colors\.red'),
    );
    expect(used.difference(reviewed), isEmpty, reason: 'chỗ dùng đỏ mới');
  });

  test('06 Bản 2 ED2-04, F05-V22, UX-AC26: mọi đường lưu "Đã tập" và buổi '
      'tập thêm đi qua hộp S-65 (confirmLock)', () {
    // Chỉ hai nơi gọi use case chốt buổi, cả hai lấy cờ từ confirmLock().
    expect(
      filesUsing(RegExp(r'markSessionDoneProvider|addExtraSessionProvider')),
      {
        'lib/features/today/application/mark_session.dart',
        'lib/features/schedule/presentation/session_marking.dart',
        'lib/features/schedule/presentation/extra_session_sheet.dart',
      },
    );
    expect(filesUsing(RegExp(r'confirmed:\s*true')), isEmpty);
    for (final f in [
      'lib/features/schedule/presentation/session_marking.dart',
      'lib/features/schedule/presentation/extra_session_sheet.dart',
    ]) {
      expect(sources[f], contains('await confirmLock('), reason: f);
    }
    // S-23 Bản 1 không còn trong code (UA2-07).
    expect(
      sources.keys.where((f) => f.contains('mark_session_sheet')),
      isEmpty,
    );
  });

  test('04 §6.17: nút chỉ có biểu tượng đều có tên đọc được (tooltip)', () {
    final missing = <String>[];
    for (final e in sources.entries) {
      for (final m in RegExp(r'IconButton\(').allMatches(e.value)) {
        // Trong phần đối số của lời gọi (không quá 400 ký tự).
        final call = e.value.substring(
          m.end,
          (m.end + 400).clamp(0, e.value.length),
        );
        if (!call.contains('tooltip:')) missing.add('${e.key}:${m.start}');
      }
    }
    expect(missing, isEmpty);
  });

  test('04 §6.16: hiệu ứng chuyển động tôn trọng "Giảm chuyển động"', () {
    // Hiệu ứng tự viết: AnimatedSwitcher, cuộn có thời lượng.
    final animated = RegExp(
      r'AnimatedSwitcher\(|Scrollable\.ensureVisible\([^;]*duration:',
    );
    for (final file in filesUsing(animated)) {
      expect(sources[file], contains('disableAnimationsOf'), reason: file);
    }
  });

  group('04 §6.15: văn phong', () {
    test('không dùng dấu chấm than trong thông báo', () {
      expect([
        for (final e in S.catalog.entries)
          if (e.value.contains('!')) e.key,
      ], isEmpty);
    });

    test('gọi người dùng là "Bạn", viết hoa chữ B', () {
      expect([
        for (final e in S.catalog.entries)
          if (RegExp(
            r'(^|[^\p{L}])bạn([^\p{L}]|$)',
            unicode: true,
          ).hasMatch(e.value))
            e.key,
      ], isEmpty);
    });
  });
}
