import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../errors/app_failure.dart';
import 'state_views.dart';

import '../tokens.dart';

/// Standard page frame inside the app shell: title row with actions, then
/// the content, centred and capped at a readable width.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.onBack,
    this.scrollable = true,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;

  /// Shows a back arrow before the title (detail and editor pages).
  final VoidCallback? onBack;

  /// When false the child gets the remaining height (for lists that scroll
  /// themselves); when true the whole page scrolls.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final compact = NobBreakpoints.isCompact(context);
    final gutter = compact ? NobSpace.lg : NobSpace.xxl;
    final sub = subtitle;
    final back = onBack;

    final heading = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (back != null) ...[
          IconButton(tooltip: 'Back', onPressed: back, icon: const Icon(Icons.arrow_back_rounded)),
          const SizedBox(width: NobSpace.sm),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text(title, style: NobText.headline)),
              if (sub != null) ...[
                const SizedBox(height: NobSpace.xs),
                Text(sub, style: NobText.body.copyWith(color: NobColors.textSecondary)),
              ],
            ],
          ),
        ),
      ],
    );

    final actionRow = Wrap(spacing: NobSpace.md, runSpacing: NobSpace.sm, children: actions);

    final header = Padding(
      padding: EdgeInsets.fromLTRB(gutter, gutter, gutter, NobSpace.lg),
      child: compact || actions.isEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading,
                if (actions.isNotEmpty) ...[const SizedBox(height: NobSpace.md), actionRow],
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: heading),
                const SizedBox(width: NobSpace.lg),
                actionRow,
              ],
            ),
    );

    final body = Padding(padding: EdgeInsets.fromLTRB(gutter, 0, gutter, gutter), child: child);

    Widget constrain(Widget content) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: NobBreakpoints.contentMax),
        child: content,
      ),
    );

    // Pages are stacked inside the shell; an opaque background keeps the
    // page underneath from showing through during transitions.
    return ColoredBox(
      color: NobColors.background,
      child: scrollable
          ? SingleChildScrollView(
              child: constrain(
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [header, body]),
              ),
            )
          : constrain(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  Expanded(child: body),
                ],
              ),
            ),
    );
  }
}

/// Lays children out in equal-width columns that collapse as space shrinks.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 240,
    this.spacing = NobSpace.lg,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = ((constraints.maxWidth + spacing) / (minItemWidth + spacing)).floor().clamp(
          1,
          6,
        );
        // Rounded down so accumulated fractions never push the last item to a new row.
        final width = ((constraints.maxWidth - spacing * (columns - 1)) / columns).floorToDouble();
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final child in children) SizedBox(width: width, child: child)],
        );
      },
    );
  }
}

/// Main content with a side panel on wide windows; stacked on narrow ones.
class TwoPane extends StatelessWidget {
  const TwoPane({super.key, required this.primary, required this.secondary});

  final Widget primary;
  final Widget secondary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 860) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              primary,
              const SizedBox(height: NobSpace.lg),
              secondary,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: primary),
            const SizedBox(width: NobSpace.lg),
            Expanded(flex: 2, child: secondary),
          ],
        );
      },
    );
  }
}

/// Page for a single record: shows loading, failure and "not found" inside
/// the standard page frame and hands the loaded record to [builder].
class DetailLoader<T> extends StatelessWidget {
  const DetailLoader({
    super.key,
    required this.value,
    required this.title,
    required this.onBack,
    required this.onRetry,
    required this.builder,
  });

  final AsyncValue<T?> value;

  /// Page title while there is no record to take one from.
  final String title;
  final VoidCallback onBack;
  final VoidCallback onRetry;
  final Widget Function(T record) builder;

  @override
  Widget build(BuildContext context) {
    Widget frame(Widget child) =>
        PageScaffold(title: title, onBack: onBack, scrollable: false, child: child);

    return value.when(
      loading: () => frame(const LoadingView()),
      error: (error, _) =>
          frame(ErrorState(message: AppFailure.from(error).message, onRetry: onRetry)),
      data: (record) => record == null
          ? frame(
              EmptyState(
                icon: Icons.search_off_rounded,
                title: '$title not found',
                message: 'It may have been deleted, or it belongs to another organization.',
              ),
            )
          : builder(record),
    );
  }
}
