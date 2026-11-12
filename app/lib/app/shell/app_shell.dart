import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/components/brand_mark.dart';
import '../../core/design_system/tokens.dart';
import '../../features/tenancy/application/tenancy_providers.dart';
import 'attention.dart';
import 'nav_destinations.dart';
import 'switchers.dart';

/// The frame around every signed-in screen.
///
/// One navigation model, three layouts: a labelled sidebar on wide windows,
/// an icon rail on medium ones and a bottom bar on phones.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});

  /// Current route path, used to highlight the active destination.
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinations = visibleDestinations(ref.watch(permissionsProvider));
    final selected = destinationIndexFor(location, destinations);
    final width = MediaQuery.sizeOf(context).width;

    void open(NavDestination destination) => context.go(destination.path);

    if (width < NobBreakpoints.compact) {
      return _CompactShell(
        destinations: destinations,
        selected: selected,
        onOpen: open,
        child: child,
      );
    }

    final expanded = width >= NobBreakpoints.expanded;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            _SideNavigation(
              destinations: destinations,
              selected: selected,
              expanded: expanded,
              onOpen: open,
            ),
            const VerticalDivider(width: 1, thickness: 1, color: NobColors.border),
            Expanded(
              child: Column(
                children: [
                  const _TopBar(showBrand: false),
                  const Divider(),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.showBrand});

  final bool showBrand;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: NobSpace.lg),
        child: Row(
          children: [
            if (showBrand) ...[const BrandMark(size: 30), const SizedBox(width: NobSpace.md)],
            const Flexible(child: WorkspaceSwitcher()),
            const Spacer(),
            const AttentionButton(),
            const SizedBox(width: NobSpace.sm),
            const UserMenu(),
          ],
        ),
      ),
    );
  }
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({
    required this.destinations,
    required this.selected,
    required this.expanded,
    required this.onOpen,
  });

  final List<NavDestination> destinations;
  final int selected;
  final bool expanded;
  final ValueChanged<NavDestination> onOpen;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    String? section;
    for (var i = 0; i < destinations.length; i++) {
      final destination = destinations[i];
      if (destination.section != section) {
        section = destination.section;
        items.add(
          expanded
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(
                    NobSpace.md,
                    NobSpace.lg,
                    NobSpace.md,
                    NobSpace.sm,
                  ),
                  child: Text(
                    destination.section.toUpperCase(),
                    style: NobText.overline.copyWith(color: NobColors.textMuted),
                  ),
                )
              : const SizedBox(height: NobSpace.md),
        );
      }
      items.add(
        _NavTile(
          destination: destination,
          selected: i == selected,
          expanded: expanded,
          onTap: () => onOpen(destination),
        ),
      );
    }

    return Material(
      color: NobColors.backgroundRaised,
      child: SizedBox(
        width: expanded ? 248 : 72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.all(expanded ? NobSpace.lg : NobSpace.md),
              child: expanded
                  ? const Align(alignment: Alignment.centerLeft, child: BrandLockup())
                  : const Center(child: BrandMark(size: 36)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: expanded ? NobSpace.md : NobSpace.lg),
              child: OrganizationSwitcher(dense: !expanded),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: NobSpace.md, vertical: NobSpace.sm),
                children: items,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.destination,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? NobColors.textPrimary : NobColors.textSecondary;
    final icon = Icon(
      selected ? destination.selectedIcon : destination.icon,
      size: 20,
      color: selected ? NobColors.cyan : NobColors.textSecondary,
    );

    final tile = Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: NobSpace.xs),
        child: Material(
          color: selected ? NobColors.cobalt.withValues(alpha: 0.22) : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: NobRadius.medium,
            side: BorderSide(
              color: selected ? NobColors.cobalt.withValues(alpha: 0.55) : Colors.transparent,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 42,
              child: expanded
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: NobSpace.md),
                      child: Row(
                        children: [
                          icon,
                          const SizedBox(width: NobSpace.md),
                          Expanded(
                            child: Text(
                              destination.label,
                              style: NobText.subtitle.copyWith(
                                color: color,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Center(child: icon),
            ),
          ),
        ),
      ),
    );

    return expanded ? tile : Tooltip(message: destination.label, child: tile);
  }
}

/// Phone layout: top bar, content, bottom bar with the first destinations
/// and a "More" sheet for the rest.
class _CompactShell extends StatelessWidget {
  const _CompactShell({
    required this.destinations,
    required this.selected,
    required this.onOpen,
    required this.child,
  });

  static const _primaryCount = 4;

  final List<NavDestination> destinations;
  final int selected;
  final ValueChanged<NavDestination> onOpen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final primary = destinations.take(_primaryCount).toList();
    final overflow = destinations.skip(_primaryCount).toList();
    final hasMore = overflow.isNotEmpty;
    final barIndex = selected < 0
        ? 0
        : selected < primary.length
        ? selected
        : primary.length;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _TopBar(showBrand: true),
            const Divider(),
            Expanded(child: child),
          ],
        ),
      ),
      bottomNavigationBar: primary.length + (hasMore ? 1 : 0) < 2
          ? null
          : NavigationBar(
              selectedIndex: barIndex,
              onDestinationSelected: (index) {
                if (index < primary.length) {
                  onOpen(primary[index]);
                } else {
                  _showMore(context, overflow);
                }
              },
              destinations: [
                for (final destination in primary)
                  NavigationDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: destination.label,
                  ),
                if (hasMore)
                  const NavigationDestination(
                    icon: Icon(Icons.menu_rounded),
                    selectedIcon: Icon(Icons.menu_open_rounded),
                    label: 'More',
                  ),
              ],
            ),
    );
  }

  void _showMore(BuildContext context, List<NavDestination> overflow) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(NobSpace.lg, 0, NobSpace.lg, NobSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: NobSpace.lg),
              child: OrganizationSwitcher(),
            ),
            for (final destination in overflow)
              ListTile(
                leading: Icon(destination.icon),
                title: Text(destination.label),
                selected: destinations.indexOf(destination) == selected,
                selectedColor: NobColors.cyan,
                shape: const RoundedRectangleBorder(borderRadius: NobRadius.medium),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onOpen(destination);
                },
              ),
          ],
        ),
      ),
    );
  }
}
