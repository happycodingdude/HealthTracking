import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/app_tab.dart';
import '../../../app/strings_vi.dart';
import '../../../core/formatters.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
import '../../library/presentation/library_screen.dart';
import '../application/session_item_edits.dart';
import '../application/session_providers.dart';

/// Đường dẫn S-75 cho buổi hôm nay [date] (04 Bản 5 §6.3): có [slot] = "Đổi
/// bài" cho chỗ của bài đó (S-74 → S-75 → về S-10); không có = "Thêm bài"
/// ("+ Thêm bài" → S-75 → về S-10).
String pickExercisePath(LocalDate date, {String? slot}) =>
    '${AppTab.today.path}/pick?date=${date.toKey()}'
    '${slot == null ? '' : '&slot=${Uri.encodeQueryComponent(slot)}'}';

/// S-75 — Chọn bài (04 Bản 5 S-75, màn con): tiêu đề "Đổi bài" / "Thêm bài"; thanh viên 7
/// nhóm cơ cuộn ngang (như S-66; chạm viên → cuộn tới nhóm, không lọc); danh
/// sách phẳng theo nhóm (tiêu đề nhóm in hoa, PD3-01) — ảnh vùng cơ tròn +
/// tên bài + ›. Ẩn bài đang có trong buổi và bài gốc đang bị thay (FC5-04);
/// nhóm không còn bài → không hiện. Chạm bài → về S-10 ngay, không hộp xác
/// nhận, thông báo nhanh "Đã đổi sang {tên}" / "Đã thêm {tên}" (bài thêm nối
/// cuối, F30-R3). Trống: chỉ icon mờ, không câu.
class PickExerciseScreen extends ConsumerStatefulWidget {
  const PickExerciseScreen({super.key, required this.date, this.slot});

  final LocalDate date;

  /// Bài đang đứng ở chỗ cần đổi (bài gốc hoặc bài thay); null = thêm bài.
  final String? slot;

  @override
  ConsumerState<PickExerciseScreen> createState() => _PickExerciseState();
}

class _PickExerciseState extends ConsumerState<PickExerciseScreen> {
  final _groupKeys = {for (final g in LibraryRules.groupOrder) g: GlobalKey()};
  MuscleGroup? _chosen;
  bool _busy = false;

  Future<void> _pick(Exercise e) async {
    if (_busy) return;
    _busy = true;
    final slot = widget.slot;
    try {
      if (slot == null) {
        await ref.read(addExtraExerciseProvider)(widget.date, e.id);
      } else {
        await ref.read(replaceExerciseProvider)(widget.date, slot, e.id);
      }
    } on SessionEditException {
      // Buổi vừa chốt hoặc đã sang ngày: về S-10, không đổi gì.
      if (mounted) context.pop();
      return;
    } finally {
      _busy = false;
    }
    if (!mounted) return;
    showToast(
      context,
      slot == null ? S.addedExercise(e.nameVi) : S.replacedTo(e.nameVi),
    );
    context.pop();
  }

  void _scrollTo(MuscleGroup g) {
    setState(() => _chosen = g);
    final target = _groupKeys[g]?.currentContext;
    if (target != null) {
      // Giảm chuyển động: nhảy thẳng tới nhóm (04 §6.16).
      Scrollable.ensureVisible(
        target,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pickable = ref.watch(pickableExercisesProvider(widget.date));
    final groups = [
      for (final g in LibraryRules.groupOrder)
        if (pickable?.any((e) => e.group == g) ?? false) g,
    ];
    final selected = _chosen ?? (groups.isEmpty ? null : groups.first);
    return IronlySubPage(
      title: widget.slot == null ? S.pickAddTitle : S.actionReplace,
      listKey: const ValueKey('pick-list'),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (final g in LibraryRules.groupOrder)
                Padding(
                  padding: const EdgeInsets.only(right: TokenSpace.s2),
                  child: IronlyChip(
                    key: ValueKey('pick-group-${g.name}'),
                    label: Fmt.muscle(g),
                    selected: g == selected,
                    onTap: groups.contains(g) ? () => _scrollTo(g) : null,
                    enabled: groups.contains(g),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: TokenSpace.s4),
        if (pickable != null && groups.isEmpty)
          const Padding(
            key: ValueKey('pick-empty'),
            padding: EdgeInsets.only(top: TokenSpace.s6),
            child: Center(child: CircleIcon(Icons.fitness_center)),
          ),
        // Mọi nhóm trong một khối dựng cùng lúc (≤ 28 bài): chạm viên của
        // nhóm ở cuối danh sách vẫn cuộn tới được (danh sách dựng lười thì
        // nhóm chưa dựng không có vị trí để cuộn).
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (gi, g) in groups.indexed) ...[
              // Nhóm đầu không tiêu đề (viên đang chọn đã cho biết nhóm — mock
              // S-75); các nhóm sau có tiêu đề in hoa.
              Padding(
                key: _groupKeys[g],
                padding: EdgeInsets.only(
                  top: gi == 0 ? 0 : TokenSpace.s5,
                  bottom: gi == 0 ? 0 : TokenSpace.s2,
                ),
                child: gi == 0
                    ? const SizedBox.shrink()
                    : Semantics(
                        header: true,
                        child: Text(
                          Fmt.muscle(g).toUpperCase(),
                          style: IronlyText.groupLabel,
                        ),
                      ),
              ),
              IronlyListCard(
                children: [
                  for (final e in pickable!)
                    if (e.group == g)
                      ExerciseRow(
                        key: ValueKey('pick-${e.id}'),
                        exercise: e,
                        onTap: () => _pick(e),
                      ),
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }
}
