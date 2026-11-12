import 'package:flutter/material.dart';

import '../../../core/design_system/components/brand_mark.dart';
import '../../../core/design_system/components/nob_card.dart';
import '../../../core/design_system/tokens.dart';

/// Shared frame for sign-in, sign-up, confirmation and reset screens: the
/// form in a card, with a brand panel beside it on wide windows.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final wide = NobBreakpoints.isExpanded(context);
    final bottom = footer;

    final form = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(NobSpace.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!wide) ...[
                const Align(alignment: Alignment.centerLeft, child: BrandLockup()),
                const SizedBox(height: NobSpace.xxl),
              ],
              NobCard(
                padding: const EdgeInsets.all(NobSpace.xxl),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: NobText.headline),
                      const SizedBox(height: NobSpace.sm),
                      Text(subtitle, style: NobText.body.copyWith(color: NobColors.textSecondary)),
                      const SizedBox(height: NobSpace.xl),
                      child,
                    ],
                  ),
                ),
              ),
              if (bottom != null) ...[const SizedBox(height: NobSpace.lg), Center(child: bottom)],
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: NobGradients.backdrop),
        child: SafeArea(
          child: wide
              ? Row(
                  children: [
                    const Expanded(flex: 5, child: _BrandPanel()),
                    Expanded(flex: 6, child: form),
                  ],
                )
              : form,
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  static const _points = <(IconData, String, String)>[
    (
      Icons.receipt_long_outlined,
      'Sell and bill',
      'Sales, quotations, invoices and payments in one flow.',
    ),
    (
      Icons.hub_outlined,
      'One place for the business',
      'Customers, catalogue, stock and documents per workspace.',
    ),
    (
      Icons.verified_user_outlined,
      'Controlled access',
      'Roles, granular permissions and an audit trail for every team.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(NobSpace.xxxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandLockup(markSize: 40),
          const Spacer(),
          const BrandMark(size: 72, glow: true),
          const SizedBox(height: NobSpace.xl),
          const Text('Run the whole business\nfrom one workspace.', style: NobText.display),
          const SizedBox(height: NobSpace.xl),
          for (final (icon, heading, body) in _points)
            Padding(
              padding: const EdgeInsets.only(bottom: NobSpace.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20, color: NobColors.cyan),
                  const SizedBox(width: NobSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(heading, style: NobText.subtitle),
                        const SizedBox(height: NobSpace.xxs),
                        Text(
                          body,
                          style: NobText.bodySmall.copyWith(color: NobColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const Spacer(),
          Text('A product of N.O Group', style: NobText.label.copyWith(color: NobColors.textMuted)),
        ],
      ),
    );
  }
}
