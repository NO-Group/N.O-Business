import 'package:flutter/material.dart';

import '../tokens.dart';

enum BadgeTone { neutral, info, success, warning, danger, accent }

/// Compact status pill. Colour is never the only signal: the label says it.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, this.tone = BadgeTone.neutral, this.icon});

  final String label;
  final BadgeTone tone;
  final IconData? icon;

  static Color colorOf(BadgeTone tone) {
    switch (tone) {
      case BadgeTone.neutral:
        return NobColors.textSecondary;
      case BadgeTone.info:
        return NobColors.cyan;
      case BadgeTone.success:
        return NobColors.success;
      case BadgeTone.warning:
        return NobColors.warning;
      case BadgeTone.danger:
        return NobColors.danger;
      case BadgeTone.accent:
        return const Color(0xFFB58CFF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorOf(tone);
    final leading = icon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: NobSpace.sm, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(NobRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            Icon(leading, size: 12, color: color),
            const SizedBox(width: NobSpace.xs),
          ],
          Text(label, style: NobText.label.copyWith(color: color)),
        ],
      ),
    );
  }
}
