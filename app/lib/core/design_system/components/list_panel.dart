import 'package:flutter/material.dart';

import '../tokens.dart';
import 'nob_card.dart';

/// A card holding a scrolling list of rows separated by hairlines.
class ListPanel extends StatelessWidget {
  const ListPanel({super.key, required this.itemCount, required this.itemBuilder, this.footer});

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// Optional note under the last row (e.g. "showing the first 200").
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final note = footer;
    final total = itemCount + (note == null ? 0 : 1);
    return NobCard(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        itemCount: total,
        separatorBuilder: (_, _) => const Divider(),
        itemBuilder: (context, index) {
          if (index >= itemCount) {
            return Padding(padding: const EdgeInsets.all(NobSpace.xl), child: note);
          }
          return itemBuilder(context, index);
        },
      ),
    );
  }
}

/// A non-scrolling list of rows inside a card, for short lists on pages that
/// scroll as a whole.
class RowGroup extends StatelessWidget {
  const RowGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const Divider(), children[i]],
      ],
    );
  }
}

/// One row: leading mark, title and subtitle, and a trailing block that
/// usually carries an amount and a status.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.dense = false,
    this.inset = NobSpace.xl,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dense;

  /// Horizontal padding; matches the card padding by default so rows line
  /// up with card headers.
  final double inset;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    final start = leading;
    final end = trailing;
    final content = Padding(
      padding: EdgeInsets.symmetric(horizontal: inset, vertical: dense ? NobSpace.sm : NobSpace.md),
      child: Row(
        children: [
          if (start != null) ...[start, const SizedBox(width: NobSpace.md)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: NobText.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (sub != null && sub.isNotEmpty) ...[
                  const SizedBox(height: NobSpace.xxs),
                  Text(
                    sub,
                    style: NobText.bodySmall.copyWith(color: NobColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (end != null) ...[const SizedBox(width: NobSpace.md), end],
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

/// Square icon tile used as the leading mark of a row.
class RowIcon extends StatelessWidget {
  const RowIcon(this.icon, {super.key, this.color = NobColors.cyan});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: NobRadius.small,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

/// Amount with an optional status underneath, right-aligned.
class TrailingAmount extends StatelessWidget {
  const TrailingAmount({super.key, required this.amount, this.below});

  final String amount;
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final extra = below;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(amount, style: NobText.numeric),
        if (extra != null) ...[const SizedBox(height: NobSpace.xs), extra],
      ],
    );
  }
}
