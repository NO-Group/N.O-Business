import 'package:flutter/material.dart';

import '../tokens.dart';

/// The standard surface: dark glass-like panel with a hairline border.
class NobCard extends StatelessWidget {
  const NobCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(NobSpace.xl),
    this.onTap,
    this.accent,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Optional luminous top edge in this colour (used sparingly, e.g. KPIs).
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final accentColor = accent;
    final content = Padding(padding: padding, child: child);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NobColors.surface,
        gradient: NobGradients.sheen,
        borderRadius: NobRadius.large,
        border: Border.all(color: NobColors.border),
      ),
      child: ClipRRect(
        borderRadius: NobRadius.large,
        child: Stack(
          children: [
            if (accentColor != null)
              Positioned(
                top: 0,
                left: NobSpace.xl,
                right: NobSpace.xl,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      accentColor.withValues(alpha: 0),
                      accentColor,
                      accentColor.withValues(alpha: 0),
                    ]),
                  ),
                ),
              ),
            if (onTap == null)
              content
            else
              Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onTap, child: content),
              ),
          ],
        ),
      ),
    );
  }
}

/// A titled block inside a page (card with a header row).
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(NobSpace.xl),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    final end = trailing;
    return NobCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: NobText.title),
                    if (sub != null) ...[
                      const SizedBox(height: NobSpace.xs),
                      Text(sub, style: NobText.bodySmall.copyWith(color: NobColors.textSecondary)),
                    ],
                  ],
                ),
              ),
              if (end != null) end,
            ],
          ),
          const SizedBox(height: NobSpace.lg),
          child,
        ],
      ),
    );
  }
}
