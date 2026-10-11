import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/theme.dart';
import '../../me/application/calorie_view.dart';

/// Nội dung một file sơ đồ cơ trong `assets/body_map/` (`male_front`,
/// `female_back`…), đọc một lần. Tự giải mã UTF-8 thay vì `loadString`: file
/// trên 50 KB thì `loadString` giải mã trên isolate khác, chậm hơn với cỡ
/// ~100 KB và không chạy trong widget test.
final bodyMapSvgProvider = FutureProvider.family<String, String>(
  (ref, file) async => utf8.decode(
    (await rootBundle.load('assets/body_map/$file.svg')).buffer.asUint8List(),
  ),
);

/// Tô màu sơ đồ cơ (05 Bản 2 §6.4.5, 06 Bản 2 ED2-10): mỗi vùng là một
/// `<g id=…>`; file không có `fill`/`stroke` nên app đặt `fill` cho từng nhóm
/// bằng xử lý chuỗi. Kết quả được nhớ theo (file, vùng, màu).
abstract final class BodyMapPainter {
  static final _cache = <String, String>{};

  /// [svg] với vùng [regionId] màu [highlight], hình dáng cơ thể màu [body],
  /// các cơ còn lại màu [muscle].
  static String colorize(
    String svg, {
    required String regionId,
    required Color highlight,
    required Color body,
    required Color muscle,
  }) {
    final key =
        '${svg.hashCode}|$regionId|${highlight.toARGB32()}|'
        '${body.toARGB32()}|${muscle.toARGB32()}';
    return _cache[key] ??= svg.replaceAllMapped(RegExp(r'<g id="([a-z_]+)">'), (
      m,
    ) {
      final id = m.group(1)!;
      final color = id == 'body'
          ? body
          : id == regionId
          ? highlight
          : muscle;
      return '<g id="$id" fill="${_hex(color)}">';
    });
  }

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}

extension on Size {
  Size shrink(double by) => Size(width - by, height - by);
}

/// Hình vùng cơ của một bài (F18-R10, 04 Bản 2 §6.10): bản nam hoặc nữ theo
/// giới tính trong hồ sơ, đổi ngay khi hồ sơ đổi; vùng của bài tô màu chủ
/// đạo. Cùng một hình cho cỡ thu nhỏ (40 × 48, dòng bài) và cỡ lớn (S-67).
class BodyMap extends ConsumerWidget {
  const BodyMap({
    super.key,
    required this.region,
    this.size = thumbnail,
    this.semanticLabel,
  });

  static const thumbnail = Size(40, 48);
  static const large = Size(104, 124);

  final MuscleRegion region;
  final Size size;

  /// Nhãn VoiceOver; null = hình trang trí (đã có tên bài, tên vùng bên cạnh).
  final String? semanticLabel;

  /// File SVG cho [sex] và mặt [view].
  static String fileOf(Sex sex, BodyView view) => '${sex.name}_${view.name}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sex = ref.watch(profileProvider).value?.sex ?? Sex.male;
    final file = fileOf(sex, region.view);
    final raw = ref.watch(bodyMapSvgProvider(file)).value;
    final palette = context.palette;
    final small = size == thumbnail;
    // Khung ngoài đúng [size]; hình nằm trong, chừa viền.
    final inner = size.shrink(small ? 4 : 16);
    final image = raw == null
        ? SizedBox.fromSize(size: inner)
        : SvgPicture.string(
            BodyMapPainter.colorize(
              raw,
              regionId: region.id,
              highlight: context.colors.primary,
              body: palette.neutralContainer,
              muscle: palette.border,
            ),
            key: ValueKey('body-map-$file-${region.id}'),
            width: inner.width,
            height: inner.height,
            excludeFromSemantics: true,
          );
    final box = Container(
      width: size.width,
      height: size.height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(small ? 8 : 14),
        border: Border.all(color: palette.border),
      ),
      child: image,
    );
    return semanticLabel == null
        ? ExcludeSemantics(child: box)
        : Semantics(image: true, label: semanticLabel, child: box);
  }
}
