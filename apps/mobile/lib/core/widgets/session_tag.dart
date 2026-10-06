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
    return Semantics(
      container: true,
      label: status.locked ? '$text, ${S.statusLocked}' : text,
      child: ExcludeSemantics(
        child: Container(
          key: ValueKey('session-tag-${status.state.name}'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: status.state == SessionState.awaitingMark ? 10 : 18,
                color: fg,
              ),
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
              if (status.locked) ...[
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
