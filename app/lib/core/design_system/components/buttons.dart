import 'package:flutter/material.dart';

import '../tokens.dart';

/// The one primary call-to-action on a view: gradient fill, clear states.
///
/// Secondary actions use the themed [OutlinedButton] / [TextButton];
/// destructive ones use [DangerButton].
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final leading = icon;
    final child = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: NobColors.onAccent),
          )
        else if (leading != null)
          Icon(leading, size: 18, color: enabled ? NobColors.onAccent : NobColors.textMuted),
        if (loading || leading != null) const SizedBox(width: NobSpace.sm),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: NobText.subtitle.copyWith(
              color: enabled || loading ? NobColors.onAccent : NobColors.textMuted,
            ),
          ),
        ),
      ],
    );

    final active = enabled || loading;
    // The button owns a Material so its gradient and ink are painted above
    // whatever surface it sits on (cards paint their own background).
    return Semantics(
      button: true,
      enabled: enabled,
      child: AnimatedOpacity(
        duration: NobMotion.fast,
        opacity: active ? 1 : 0.7,
        child: Material(
          color: Colors.transparent,
          borderRadius: NobRadius.medium,
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              gradient: active ? NobGradients.action : null,
              color: active ? null : NobColors.surfaceHigh,
            ),
            child: InkWell(
              onTap: enabled ? onPressed : null,
              hoverColor: Colors.white.withValues(alpha: 0.08),
              splashColor: Colors.white.withValues(alpha: 0.14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: NobSpace.xl, vertical: NobSpace.md),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Destructive action (void, remove, delete).
class DangerButton extends StatelessWidget {
  const DangerButton({super.key, required this.label, required this.onPressed, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      foregroundColor: NobColors.danger,
      side: BorderSide(color: NobColors.danger.withValues(alpha: 0.6)),
    );
    final leading = icon;
    if (leading == null) {
      return OutlinedButton(onPressed: onPressed, style: style, child: Text(label));
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: style,
      icon: Icon(leading, size: 18),
      label: Text(label),
    );
  }
}
