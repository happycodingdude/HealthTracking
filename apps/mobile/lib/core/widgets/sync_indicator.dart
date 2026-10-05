import 'package:flutter/material.dart';

import '../../app/strings_vi.dart';
import '../../app/theme.dart';

/// "Chưa đồng bộ" kèm đám mây gạch chéo ở đầu Hôm nay (F09-E1, 04 §6.14).
/// Màu trung tính: không phải lỗi, không có banner mất mạng toàn app.
class SyncIndicator extends StatelessWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final color = context.palette.neutral;
    return Semantics(
      label: S.syncPending,
      child: ExcludeSemantics(
        child: Container(
          key: const ValueKey('sync-indicator'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: context.palette.neutralContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                S.syncPending,
                style: context.text.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
