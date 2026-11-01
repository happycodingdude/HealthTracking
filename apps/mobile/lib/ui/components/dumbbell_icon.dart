import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Thanh tạ nằm ngang như icon app và hình mẫu (04 Bản 4 §6.1, S-01, §6.8):
/// icon Material `fitness_center` vẽ chéo 45°, xoay về ngang.
class DumbbellIcon extends StatelessWidget {
  const DumbbellIcon({super.key, required this.size, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -math.pi / 4,
    child: Icon(Icons.fitness_center, size: size, color: color),
  );
}
