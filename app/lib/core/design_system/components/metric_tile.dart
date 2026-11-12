import 'package:flutter/material.dart';

import '../tokens.dart';
import 'nob_card.dart';

/// A headline number with its label and a line of context.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.caption,
    this.color = NobColors.cyan,
    this.captionColor,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? caption;
  final Color color;
  final Color? captionColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final note = caption;
    return Semantics(
      container: true,
      button: onTap != null,
      label: '$label: $value${note == null ? '' : ', $note'}',
      excludeSemantics: true,
      child: NobCard(
        padding: const EdgeInsets.all(NobSpace.lg),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: NobRadius.small,
                  ),
                  child: Icon(icon, size: 17, color: color),
                ),
                const SizedBox(width: NobSpace.sm),
                Expanded(
                  child: Text(
                    label,
                    style: NobText.label.copyWith(color: NobColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onTap != null)
                  const Icon(Icons.north_east_rounded, size: 14, color: NobColors.textMuted),
              ],
            ),
            const SizedBox(height: NobSpace.md),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: NobText.metric, maxLines: 1),
            ),
            const SizedBox(height: NobSpace.xs),
            Text(
              note ?? ' ',
              style: NobText.bodySmall.copyWith(color: captionColor ?? NobColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
