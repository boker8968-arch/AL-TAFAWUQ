import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TafawuqBrandMark extends StatelessWidget {
  const TafawuqBrandMark({super.key, this.size = 54, this.compact = false});

  final double size;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.gold, AppColors.paleGold],
        ),
        borderRadius: BorderRadius.circular(size * .30),
        boxShadow: [
          BoxShadow(
            color: AppColors.dark.withValues(alpha: .16),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Icon(
        Icons.school_rounded,
        size: size * .57,
        color: AppColors.deepEmerald,
      ),
    );
  }
}

class TafawuqBrandLockup extends StatelessWidget {
  const TafawuqBrandLockup({super.key, this.light = false, this.markSize = 48});

  final bool light;
  final double markSize;

  @override
  Widget build(BuildContext context) {
    final foreground = light ? Colors.white : AppColors.deepEmerald;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TafawuqBrandMark(size: markSize),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('التفوق', style: TextStyle(
              color: foreground, fontSize: 23, fontWeight: FontWeight.w900,
              height: 1.1,
            )),
            Text('منصة تعليمية سودانية', style: TextStyle(
              color: light ? Colors.white70 : AppColors.muted,
              fontSize: 11, fontWeight: FontWeight.w600,
            )),
          ],
        ),
      ],
    );
  }
}
