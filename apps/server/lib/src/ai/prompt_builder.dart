import 'package:domain/domain.dart';

import 'ai_provider.dart';

/// Dựng yêu cầu tạo thực đơn (06 VS12-T05). TR-12: chỉ gửi giới tính, tuổi,
/// mức calo dùng cho thực đơn và (khi gợi ý lại) tên các món của thực đơn
/// trước. Không gửi tên, số điện thoại, lịch sử cân nặng.
abstract final class PromptBuilder {
  static const system =
      'Bạn là trợ lý gợi ý thực đơn tham khảo cho người Việt khỏe mạnh đang '
      'muốn giảm mỡ. Gợi ý thực đơn cho cả một ngày:\n'
      '- Đúng 1 bữa sáng (breakfast), 1 bữa trưa (lunch), 1 bữa tối '
      '(dinner); thêm 0–2 bữa phụ (snack) nếu phù hợp.\n'
      '- Liệt kê các bữa theo thứ tự trong ngày. Bữa phụ đặt trước bữa trưa '
      'là bữa phụ sáng, đặt sau bữa trưa là bữa phụ chiều.\n'
      '- Ưu tiên món Việt quen thuộc, nguyên liệu dễ mua, dễ nấu. Không dùng '
      'chế độ ăn kiêng đặc biệt.\n'
      '- Mỗi bữa có ít nhất 1 món. Mỗi món gồm: tên món bằng tiếng Việt (tối '
      'đa 60 ký tự), khẩu phần ước lượng (ví dụ "1 tô", "150 g", "1,5 chén"), '
      'calo ước tính là số nguyên.\n'
      '- Tổng calo của mọi món phải sát mức calo yêu cầu, chênh không quá 5%.\n'
      '- Chỉ trả về JSON đúng schema, không thêm lời giải thích.';

  /// JSON schema của đầu ra (05 §6.9.4).
  static const schema = <String, Object?>{
    'type': 'object',
    'properties': {
      'meals': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'type': {
              'type': 'string',
              'enum': ['breakfast', 'lunch', 'dinner', 'snack'],
            },
            'dishes': {
              'type': 'array',
              'items': {
                'type': 'object',
                'properties': {
                  'name': {'type': 'string'},
                  'portion': {'type': 'string'},
                  'kcal': {'type': 'integer'},
                },
                'required': ['name', 'portion', 'kcal'],
                'additionalProperties': false,
              },
            },
          },
          'required': ['type', 'dishes'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['meals'],
    'additionalProperties': false,
  };

  static AiRequest menu({
    required Sex sex,
    required int age,
    required int targetKcal,
    required int maxTokens,
    List<String> previousDishes = const [],
  }) {
    final sexText = sex == Sex.male ? 'Nam' : 'Nữ';
    final user = StringBuffer()
      ..writeln('Giới tính: $sexText.')
      ..writeln('Tuổi: $age.')
      ..writeln('Mức calo cả ngày: $targetKcal kcal.');
    if (previousDishes.isNotEmpty) {
      user.writeln(
        'Đây là lần gợi ý lại. Tránh lặp lại các món của thực đơn trước: '
        '${previousDishes.join(', ')}.',
      );
    }
    return AiRequest(
      system: system,
      user: user.toString().trim(),
      schema: schema,
      maxTokens: maxTokens,
      targetKcal: targetKcal,
      avoidDishes: previousDishes,
    );
  }
}
