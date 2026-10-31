import 'package:flutter/material.dart';

import '../app/strings_vi.dart';
import 'components/components.dart';
import 'theme.dart';

/// Đường dẫn trang thành phần (chỉ flavor dev, 06 Bản 4 VS-43 demo).
const galleryPath = '/dev/gallery';

/// Trang "component gallery": mọi thành phần dùng chung của Bản 4 ở mọi
/// trạng thái, đối chiếu với phần "Nền tảng" của mock (04 Bản 4 §6.1, §6.2).
/// Chỉ có trong flavor dev; cũng dùng cho golden thành phần.
class ComponentGallery extends StatefulWidget {
  const ComponentGallery({super.key, this.showBack = true});

  final bool showBack;

  @override
  State<ComponentGallery> createState() => _ComponentGalleryState();
}

class _ComponentGalleryState extends State<ComponentGallery> {
  final _text = TextEditingController(text: '175');
  final _empty = TextEditingController();
  final _number = TextEditingController(text: '72,4');
  bool _switch = true;
  String _segment = 'a';

  @override
  void dispose() {
    _text.dispose();
    _empty.dispose();
    _number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget section(String name) => Padding(
      padding: const EdgeInsets.only(top: TokenSpace.s6, bottom: TokenSpace.s2),
      child: Text(name.toUpperCase(), style: IronlyText.groupLabel),
    );
    return IronlySubPage(
      title: 'Gallery',
      leading: widget.showBack ? null : const SizedBox.shrink(),
      listKey: const ValueKey('gallery-list'),
      children: [
        section('Card'),
        IronlyCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Card title 13', style: IronlyText.cardTitle),
                  ),
                  Text(
                    '40 → 50',
                    style: IronlyText.liftNumber.copyWith(color: t.accent),
                  ),
                ],
              ),
              const SizedBox(height: TokenSpace.s3),
              Row(
                children: [
                  const ExerciseAvatar(
                    ring: true,
                    child: Icon(Icons.accessibility_new, size: 18),
                  ),
                  const SizedBox(width: TokenSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Main line 14', style: IronlyText.exerciseName),
                        Text('Sub line 11 gray', style: IronlyText.caption),
                      ],
                    ),
                  ),
                  Text('40 → 50', style: IronlyText.liftNumber),
                ],
              ),
              const Divider(height: TokenSpace.s4),
              Row(
                children: [
                  const ExerciseAvatar(
                    dim: true,
                    child: Icon(Icons.accessibility_new, size: 18),
                  ),
                  const SizedBox(width: TokenSpace.s3),
                  Expanded(child: Text('Main line', style: IronlyText.body)),
                  Text('gray', style: IronlyText.liftPrefill),
                ],
              ),
            ],
          ),
        ),
        const CardGap(),
        IronlyListCard(
          children: [
            IronlyRow(
              title: 'Row with value',
              subtitle: S.profileSummary(175, S.sexMale),
              leading: const CircleIcon(Icons.person_outline),
              chevron: true,
              onTap: () {},
            ),
            IronlyRow(
              title: 'Row with dot',
              subtitle: S.calorieSummary('2.210 kcal', S.calorieAuto),
              leading: const CircleIcon(Icons.soup_kitchen_outlined),
              dot: true,
              chevron: true,
              onTap: () {},
            ),
            IronlyRow(
              title: 'Row with switch',
              subtitle: S.remindersHint,
              leading: const CircleIcon(Icons.notifications_none),
              trailing: IronlySwitch(
                value: _switch,
                onChanged: (v) => setState(() => _switch = v),
              ),
            ),
          ],
        ),
        section('Button'),
        IronlyButton.primary(label: 'Primary', onPressed: () {}),
        const SizedBox(height: TokenSpace.s2),
        IronlyButton.secondary(label: 'Secondary', onPressed: () {}),
        const SizedBox(height: TokenSpace.s2),
        IronlyButton.gray(label: 'Gray', onPressed: () {}),
        const SizedBox(height: TokenSpace.s2),
        IronlyButton.danger(label: 'Danger (red)', onPressed: () {}),
        const SizedBox(height: TokenSpace.s2),
        IronlyButton.primary(
          label: 'Disabled',
          onPressed: () {},
          enabled: false,
        ),
        const SizedBox(height: TokenSpace.s2),
        IronlyButton.primary(label: 'Loading', onPressed: () {}, loading: true),
        const SizedBox(height: TokenSpace.s2),
        Wrap(
          spacing: TokenSpace.s2,
          runSpacing: TokenSpace.s2,
          children: [
            IronlyButton(
              label: '+ Extra',
              onPressed: () {},
              kind: IronlyButtonKind.secondary,
              small: true,
              expand: false,
            ),
            IronlyButton(
              label: 'Small',
              onPressed: () {},
              small: true,
              expand: false,
            ),
            IronlyButton(
              label: 'Accent outline',
              onPressed: () {},
              kind: IronlyButtonKind.secondaryAccent,
              expand: false,
            ),
          ],
        ),
        section('Segment · Chip'),
        SegmentBar<String>(
          items: const ['a', 'b', 'c'],
          selected: _segment,
          label: (i) => switch (i) {
            'a' => 'Selected',
            'b' => 'Item',
            _ => 'Item',
          },
          onSelected: (i) => setState(() => _segment = i),
        ),
        const SizedBox(height: TokenSpace.s2),
        SegmentBar<String>(
          items: const ['kg', 'steps'],
          selected: 'kg',
          style: SegmentStyle.accent,
          label: (i) => i == 'kg' ? S.unitKg : S.unitStepsFull,
          onSelected: (_) {},
        ),
        const SizedBox(height: TokenSpace.s2),
        Wrap(
          spacing: TokenSpace.s2,
          runSpacing: TokenSpace.s2,
          children: [
            IronlyChip(label: S.muscleChest, selected: true, onTap: () {}),
            IronlyChip(label: S.muscleBack, selected: false, onTap: () {}),
            IronlyChip(label: S.muscleShoulders, selected: false, onTap: () {}),
          ],
        ),
        section('Field'),
        IronlyTextField(name: 'demo', hint: 'Text field', controller: _text),
        const SizedBox(height: TokenSpace.s2),
        IronlyTextField(
          name: 'demo-error',
          hint: 'Error field',
          controller: _empty,
          error: S.invalidPhone,
        ),
        const SizedBox(height: TokenSpace.s2),
        NumberField(
          name: 'demo-number',
          label: S.fieldHeight,
          controller: _text,
          unit: 'cm',
        ),
        const SizedBox(height: TokenSpace.s2),
        BigNumberField(
          name: 'demo-big',
          controller: _number,
          unit: S.unitKg,
          active: true,
          style: IronlyText.numberField,
        ),
        section('Glyph'),
        IronlyListCard(
          children: [
            for (final (g, label) in [
              (GlyphStatus.done, S.sessionDone),
              (GlyphStatus.skipped, S.sessionSkipped),
              (GlyphStatus.pending, S.statusAwaiting),
              (GlyphStatus.upcoming, S.statusUpcoming),
              (GlyphStatus.rest, S.rest),
              (GlyphStatus.extra, S.extraSession),
              (GlyphStatus.locked, S.statusLocked),
              (GlyphStatus.markDone, S.sessionDone),
            ])
              IronlyRow(
                title: label,
                leading: StatusGlyph(g, label: label),
                minHeight: 44,
              ),
          ],
        ),
        const CardGap(),
        IronlyCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WeekStrip(
                days: [
                  for (final (i, s) in const [
                    GlyphStatus.done,
                    GlyphStatus.pending,
                    GlyphStatus.upcoming,
                    GlyphStatus.rest,
                    GlyphStatus.extra,
                    GlyphStatus.skipped,
                  ].indexed)
                    (
                      dateKey: 'd$i',
                      label: S.weekdaysShort[i],
                      status: s,
                      semantics: s.name,
                      highlighted: i == 1,
                    ),
                ],
              ),
              const SizedBox(height: TokenSpace.s4),
              const ProgressDots(
                dots: [
                  DotState.done,
                  DotState.done,
                  DotState.today,
                  DotState.idle,
                ],
                label: '2/4',
              ),
            ],
          ),
        ),
        const CardGap(),
        IronlyCard(
          child: MonthGrid(
            weekdayLabels: S.weekdaysShort,
            leading: 3,
            cells: [
              for (var d = 1; d <= 14; d++)
                (
                  dateKey: 'm$d',
                  day: d,
                  kind: switch (d % 5) {
                    0 => MonthCellKind.done,
                    1 => MonthCellKind.rest,
                    2 => MonthCellKind.upcoming,
                    3 => MonthCellKind.skipped,
                    _ => MonthCellKind.today,
                  },
                  extra: d == 7,
                  overridden: d == 12,
                  semantics: 'day $d',
                ),
            ],
            onTap: (_) {},
          ),
        ),
        section('Banner · Empty · Skeleton'),
        IronlyBanner(
          text: S.offlineMenu,
          actionLabel: S.retry,
          onAction: () {},
        ),
        const CardGap(),
        EmptyAction(
          icon: Icons.soup_kitchen_outlined,
          action: IronlyButton.primary(label: S.generateMenu, onPressed: () {}),
          caption: S.remainingToday(3),
        ),
        const CardGap(),
        const IronlyCard(child: SkeletonLines(lines: 3)),
        section('Dialog · Sheet'),
        IronlyButton.gray(
          label: 'Open dialog',
          onPressed: () => showIronlyDialog<void>(
            context,
            builder: (_) => IronlyDialog(
              title: 'Dialog title',
              body: 'Dialog body text, two buttons.',
              secondaryLabel: S.cancel,
              onSecondary: () => Navigator.of(context).pop(),
              primaryLabel: 'OK',
              onPrimary: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        const SizedBox(height: TokenSpace.s2),
        IronlyButton.gray(
          label: 'Open sheet',
          onPressed: () => showIronlySheet<void>(
            context,
            builder: (_) => IronlySheet(
              title: 'Sheet',
              footer: IronlyButton.primary(
                label: S.save,
                onPressed: () => Navigator.of(context).pop(),
              ),
              children: [
                Text(
                  'Scrim behind, swipe down to close.',
                  style: IronlyText.caption,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: TokenSpace.s2),
        IronlyButton.gray(
          label: 'Toast',
          onPressed: () => showToast(context, 'Toast 3 seconds'),
        ),
      ],
    );
  }
}
