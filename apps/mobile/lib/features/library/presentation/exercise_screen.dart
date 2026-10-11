import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/heading.dart';
import '../../../core/widgets/reference_tag.dart';
import '../application/library_providers.dart';
import 'body_map.dart';
import 'video_area.dart';

/// Màn trước của S-67: quyết định chữ trên nút quay lại (04 Bản 2 S-67).
enum ExerciseFrom {
  library(S.backLibrary),
  session(S.backSession),
  progress(S.backProgress);

  const ExerciseFrom(this.backLabel);

  final String backLabel;

  static ExerciseFrom parse(String? name) => values.firstWhere(
    (f) => f.name == name,
    orElse: () => ExerciseFrom.library,
  );
}

/// Đường dẫn S-67, nằm trong tab Tập luyện (NAV-10).
String exercisePath(String id, ExerciseFrom from) =>
    '/schedule/exercise/${Uri.encodeComponent(id)}?from=${from.name}';

/// S-67 — Chi tiết bài (04 Bản 2 §6.8, F-19): video, tên, nhóm · vùng ·
/// dụng cụ, hình vùng cơ (nam/nữ theo hồ sơ), Cách tập, Lưu ý an toàn, nhãn
/// "tham khảo" của hướng dẫn (F10-R21). Tên, hình, hướng dẫn hiện được khi
/// không có mạng; chỉ video cần mạng (F19-R2). Hướng dẫn hiện đúng nội dung
/// Bạn đã duyệt (F19-R5). Khu mức tạ thêm ở VS-27, VS-28.
class ExerciseScreen extends ConsumerWidget {
  const ExerciseScreen({super.key, required this.id, required this.from});

  final String id;
  final ExerciseFrom from;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercise = ref.watch(exerciseProvider(id)).value;
    final palette = context.palette;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('exercise-back'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.only(right: 12),
                ),
                onPressed: () => context.pop(),
                icon: const Icon(Icons.chevron_left),
                label: Text(from.backLabel),
              ),
            ),
            const SizedBox(height: 12),
            if (exercise != null) ...[
              VideoArea(exercise: exercise),
              const SizedBox(height: 20),
              Heading(
                exercise.nameVi,
                style: context.text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              // Ngay dưới tên bài (bảng khu mức tạ của S-67, F19-E2).
              if (!exercise.active) ...[
                const SizedBox(height: 4),
                Text(
                  S.notInLibrary,
                  key: const ValueKey('not-in-library'),
                  style: context.text.bodyMedium?.copyWith(
                    color: palette.attention,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                '${Fmt.muscle(exercise.group)} · '
                '${Fmt.region(exercise.region)} · '
                '${Fmt.equipment(exercise.equipment)}',
                style: context.text.bodyLarge?.copyWith(
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  BodyMap(
                    region: exercise.region,
                    size: BodyMap.large,
                    semanticLabel:
                        '${S.mainRegion}: ${Fmt.region(exercise.region)}',
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ExcludeSemantics(
                      child: Text(
                        S.mainRegion,
                        style: context.text.bodyLarge?.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const _SectionTitle(S.howTo),
              for (final (i, step) in exercise.guideSteps.indexed)
                _GuideLine(marker: '${i + 1}', text: step),
              const SizedBox(height: 16),
              const _SectionTitle(S.safetyNotes),
              for (final note in exercise.guideSafety)
                _GuideLine(marker: '•', text: note),
              const SizedBox(height: 16),
              const _GuideNote(),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: text,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            text.toUpperCase(),
            style: context.text.labelLarge?.copyWith(
              color: context.palette.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

/// Một bước (đánh số) hoặc một ý (gạch đầu dòng) của hướng dẫn.
class _GuideLine extends StatelessWidget {
  const _GuideLine({required this.marker, required this.text});

  final String marker;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.2,
                child: Text(
                  marker,
                  style: context.text.labelLarge?.copyWith(
                    color: context.colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(text, style: context.text.bodyLarge),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nhãn của hướng dẫn bài tập (F10-R21). Chạm → bảng giải thích như nhãn
/// "tham khảo" của Bản 1 (04 Bản 2 S-67).
class _GuideNote extends StatelessWidget {
  const _GuideNote();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: S.exerciseGuideNote,
      child: ExcludeSemantics(
        child: InkWell(
          key: const ValueKey('exercise-guide-note'),
          borderRadius: BorderRadius.circular(14),
          onTap: () => showReferenceSheet(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: context.palette.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.palette.border),
            ),
            child: Text(
              S.exerciseGuideNote,
              style: context.text.bodyMedium?.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
