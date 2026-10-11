import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import '../../app/strings_vi.dart';
import '../../app/theme.dart';

/// Nhãn trạng thái buổi tập (04 §6.13.3). Không dùng màu làm cách phân biệt
/// duy nhất: mỗi trạng thái có biểu tượng và chữ; buổi đã khóa thêm ổ khóa
/// nhỏ. VoiceOver đọc chữ (04 §6.17).
class SessionTag extends StatelessWidget {
  const SessionTag(this.status, {super.key});

  final SessionStatus status;

  static String label(SessionState state) => switch (state) {
    SessionState.upcoming => S.statusUpcoming,
    SessionState.awaitingMark => S.statusAwaiting,
    SessionState.done => S.sessionDone,
    SessionState.skipped => S.sessionSkipped,
    SessionState.autoSkipped => S.statusAutoSkipped,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (Color fg, Color bg, IconData icon) = switch (status.state) {
      SessionState.upcoming => (
        palette.neutral,
        palette.neutralContainer,
        Icons.schedule,
      ),
      SessionState.awaitingMark => (
        palette.attention,
        palette.attentionContainer,
        Icons.circle,
      ),
      SessionState.done => (
        palette.success,
        palette.successContainer,
        Icons.check,
      ),
      SessionState.skipped || SessionState.autoSkipped => (
        palette.neutral,
        palette.neutralContainer,
        Icons.remove,
      ),
    };
    final text = label(status.state);
    return _TagChip(
      key: ValueKey('session-tag-${status.state.name}'),
      semantics: status.locked ? '$text, ${S.statusLocked}' : text,
      text: text,
      icon: icon,
      iconSize: status.state == SessionState.awaitingMark ? 10 : 18,
      fg: fg,
      bg: bg,
      locked: status.locked,
    );
  }
}

/// Nhãn "Buổi tập thêm" (04 §6.13.3): xanh ngọc, dấu cộng.
class ExtraSessionTag extends StatelessWidget {
  const ExtraSessionTag({super.key});

  @override
  Widget build(BuildContext context) => _TagChip(
    key: const ValueKey('session-tag-extra'),
    semantics: S.extraSession,
    text: S.extraSession,
    icon: Icons.add,
    iconSize: 18,
    fg: context.colors.onPrimaryContainer,
    bg: context.colors.primaryContainer,
  );
}

/// Nhãn "Đã lưu" của buổi tập thêm ở S-63 (mock S-63-3): buổi tập thêm chỉ
/// có một trạng thái, chốt ngay khi lưu (03 Bản 2 §6.1).
class ExtraSavedTag extends StatelessWidget {
  const ExtraSavedTag({super.key});

  @override
  Widget build(BuildContext context) => _TagChip(
    key: const ValueKey('session-tag-extra-saved'),
    semantics: S.extraSaved,
    text: S.extraSaved,
    icon: Icons.add,
    iconSize: 18,
    fg: context.colors.onPrimaryContainer,
    bg: context.colors.primaryContainer,
  );
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    super.key,
    required this.semantics,
    required this.text,
    required this.icon,
    required this.iconSize,
    required this.fg,
    required this.bg,
    this.locked = false,
  });

  final String semantics;
  final String text;
  final IconData icon;
  final double iconSize;
  final Color fg;
  final Color bg;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semantics,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: iconSize, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  text,
                  style: context.text.labelLarge?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (locked) ...[
                const SizedBox(width: 6),
                Icon(Icons.lock, size: 16, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
