import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/strings_vi.dart';
import '../../../core/formatters.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
import '../../native/gym_region_bridge.dart';
import '../application/gym_location.dart';

/// `/me/gym` (04 Bản 5 §6.3).
const gymLocationPath = '/me/gym';

/// "Lưu lúc 17:20 · T3 03/11/2026" (04 Bản 5 S-77, F32-R2): chỉ giờ lưu,
/// không tọa độ, không địa chỉ.
String gymSavedAtText(GymLocation g) {
  final at = g.savedAt.toLocal();
  final date = LocalDate.fromDateTime(at);
  final year = date.year.toString().padLeft(4, '0');
  return S.gymSavedAt(Fmt.clock(at), '${Fmt.shortWeekdayDate(date)}/$year');
}

/// S-77 — Vị trí phòng gym (04 Bản 5 §6.6 S-77; 03 Bản 5 F-32).
///
/// - Chưa lưu: thẻ ghim 64 thẻ nổi + "Lưu vị trí này" cam; công tắc mờ.
/// - Đang lấy vị trí: vòng xoay cam + "Đang lấy vị trí…" thay nút.
/// - Đã lưu: ghim viền cam (công tắc tắt: không viền); "Lưu lúc …"; "Lưu lại
///   vị trí này" xám (hộp); công tắc; "Quyền vị trí" (chỉ thông tin, chạm mở
///   Cài đặt); "Xóa vị trí" đỏ (hộp).
/// - Không lấy được vị trí: banner viền cam F32-R3 + "Mở Cài đặt".
class GymLocationScreen extends ConsumerStatefulWidget {
  const GymLocationScreen({super.key});

  @override
  ConsumerState<GymLocationScreen> createState() => _GymLocationScreenState();
}

class _GymLocationScreenState extends ConsumerState<GymLocationScreen> {
  bool _fetching = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Quyền đọc lại mỗi lần mở S-77 (05 Bản 5 §6.4.6).
    Future.microtask(() {
      if (mounted) ref.invalidate(locationAccessProvider);
    });
  }

  Future<void> _save({required bool resave}) async {
    if (resave) {
      final ok =
          await showIronlyDialog<bool>(
            context,
            builder: (dialogContext) => IronlyDialog(
              title: S.resaveGymTitle,
              body: S.resaveGymBody,
              secondaryLabel: S.cancel,
              onSecondary: () => Navigator.of(dialogContext).pop(false),
              primaryLabel: S.resaveGymAction,
              primaryKey: const ValueKey('confirm-resave-gym'),
              onPrimary: () => Navigator.of(dialogContext).pop(true),
            ),
          ) ??
          false;
      if (!ok || !mounted) return;
    }
    setState(() {
      _fetching = true;
      _failed = false;
    });
    final result = await ref.read(gymLocationEditsProvider).save();
    if (!mounted) return;
    ref.invalidate(locationAccessProvider);
    setState(() {
      _fetching = false;
      _failed = result == GymSaveResult.noFix;
    });
    if (result == GymSaveResult.saved) showToast(context, S.gymSaved);
  }

  Future<void> _delete() async {
    final ok =
        await showIronlyDialog<bool>(
          context,
          builder: (dialogContext) => IronlyDialog(
            title: S.deleteGymTitle,
            body: S.deleteGymBody,
            secondaryLabel: S.cancel,
            onSecondary: () => Navigator.of(dialogContext).pop(false),
            primaryLabel: S.delete,
            destructive: true,
            primaryKey: const ValueKey('confirm-delete-gym'),
            onPrimary: () => Navigator.of(dialogContext).pop(true),
          ),
        ) ??
        false;
    if (!ok || !mounted) return;
    await ref.read(gymLocationEditsProvider).delete();
  }

  static String _access(LocationAccess a) => switch (a) {
    LocationAccess.always => S.locationAlways,
    LocationAccess.whenInUse => S.locationWhenInUse,
    LocationAccess.denied || LocationAccess.notDetermined => S.locationNone,
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final saved = ref.watch(gymLocationProvider).value;
    final access = ref.watch(locationAccessProvider).value;
    final on = saved?.enabled ?? false;
    final bridge = ref.read(gymRegionBridgeProvider);
    return IronlySubPage(
      title: S.gymLocation,
      children: [
        IronlyCard(
          key: const ValueKey('gym-card'),
          child: Column(
            children: [
              const SizedBox(height: TokenSpace.s2),
              ExcludeSemantics(
                child: CircleIcon(
                  key: const ValueKey('gym-pin'),
                  Icons.location_on_outlined,
                  size: 64,
                  color: saved == null ? t.textSecondary : t.accent,
                  ring: saved != null && on ? t.accent : null,
                ),
              ),
              if (saved != null) ...[
                const SizedBox(height: TokenSpace.s4),
                Text(
                  gymSavedAtText(saved),
                  key: const ValueKey('gym-saved-at'),
                  textAlign: TextAlign.center,
                  style: IronlyText.body,
                ),
              ],
              const SizedBox(height: TokenSpace.s4),
              if (_fetching)
                SizedBox(
                  key: const ValueKey('gym-fetching'),
                  height: 52,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: t.accent,
                        ),
                      ),
                      const SizedBox(width: TokenSpace.s3),
                      Flexible(
                        child: Text(
                          S.gettingLocation,
                          style: IronlyText.body.copyWith(
                            color: t.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (saved == null)
                IronlyButton.primary(
                  key: const ValueKey('gym-save'),
                  label: S.saveGymLocation,
                  onPressed: () => _save(resave: false),
                )
              else
                IronlyButton.gray(
                  key: const ValueKey('gym-resave'),
                  label: S.resaveGymLocation,
                  onPressed: () => _save(resave: true),
                ),
              const SizedBox(height: TokenSpace.s2),
            ],
          ),
        ),
        if (_failed) ...[
          const CardGap(),
          IronlyBanner(
            key: const ValueKey('gym-error'),
            text: S.gymNoFix,
            actionLabel: S.openSettings,
            onAction: bridge.openSettings,
          ),
        ],
        const CardGap(),
        IronlyListCard(
          children: [
            IronlyRow(
              key: const ValueKey('row-gym-switch'),
              title: S.gymCardSwitch,
              titleStyle: saved == null
                  ? IronlyText.body.copyWith(color: t.textSecondary)
                  : null,
              trailing: IronlySwitch(
                key: const ValueKey('gym-switch'),
                value: on,
                label: S.gymCardSwitch,
                // F32-R4: chưa lưu vị trí thì công tắc mờ.
                onChanged: saved == null
                    ? null
                    : (v) => ref.read(gymLocationEditsProvider).setEnabled(v),
              ),
            ),
            if (saved != null)
              IronlyRow(
                key: const ValueKey('row-gym-permission'),
                title: S.locationPermission,
                value: access == null ? '' : _access(access),
                onTap: bridge.openSettings,
              ),
          ],
        ),
        if (saved != null) ...[
          const SizedBox(height: TokenSpace.s3),
          Center(
            child: IronlyButton(
              key: const ValueKey('gym-delete'),
              kind: IronlyButtonKind.danger,
              expand: false,
              label: S.deleteGymLocation,
              onPressed: _delete,
            ),
          ),
        ],
      ],
    );
  }
}
