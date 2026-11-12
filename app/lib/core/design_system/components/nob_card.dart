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
    final tap = onTap;
    final content = Padding(padding: padding, child: child);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NobColors.surface,
        gradient: NobGradients.sheen,
        borderRadius: NobRadius.large,
        border: Border.all(color: NobColors.border),
      ),
      // The card owns a transparent Material so list tiles and ink effects
      // inside it are painted above the card's own background.
      child: Material(
        type: MaterialType.transparency,
        borderRadius: NobRadius.large,
        clipBehavior: Clip.antiAlias,
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
                    gradient: LinearGradient(
                      colors: [accentColor.withValues(alpha: 0), accentColor, accentColor.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
            if (tap == null) content else InkWell(onTap: tap, child: content),
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
    this.flush = false,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Lets [child] run edge to edge (for lists of tappable rows); only the
  /// header keeps the card padding.
  final bool flush;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    final end = trailing;
    final header = _header(sub, end);
    return NobCard(
      padding: flush ? EdgeInsets.zero : padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (flush)
            Padding(
              padding: const EdgeInsets.fromLTRB(NobSpace.xl, NobSpace.xl, NobSpace.xl, 0),
              child: header,
            )
          else
            header,
          SizedBox(height: flush ? NobSpace.md : NobSpace.lg),
          child,
          if (flush) const SizedBox(height: NobSpace.md),
        ],
      ),
    );
  }

  Widget _header(String? sub, Widget? end) {
    return Row(
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
              ?end,
            ],
          );
  }
}
