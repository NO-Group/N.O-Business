import 'package:flutter/material.dart';

import '../../features/tenancy/domain/permissions.dart';
import '../app_gate.dart';

/// One entry in the main navigation.
class NavDestination {
  const NavDestination({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.section,
    this.permission,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String section;

  /// Permission needed to open the module; null means every member.
  final String? permission;
}

/// The single navigation model used by the sidebar, the rail and the bottom
/// bar, so every form factor exposes the same modules in the same order.
const List<NavDestination> navDestinations = [
  NavDestination(
    path: Routes.dashboard,
    label: 'Dashboard',
    icon: Icons.space_dashboard_outlined,
    selectedIcon: Icons.space_dashboard_rounded,
    section: 'Overview',
  ),
  NavDestination(
    path: Routes.sales,
    label: 'Sales',
    icon: Icons.point_of_sale_outlined,
    selectedIcon: Icons.point_of_sale_rounded,
    section: 'Revenue',
    permission: Permissions.salesRead,
  ),
  NavDestination(
    path: Routes.invoices,
    label: 'Invoices',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long_rounded,
    section: 'Revenue',
    permission: Permissions.invoicesRead,
  ),
  NavDestination(
    path: Routes.quotations,
    label: 'Quotations',
    icon: Icons.request_quote_outlined,
    selectedIcon: Icons.request_quote_rounded,
    section: 'Revenue',
    permission: Permissions.quotationsRead,
  ),
  NavDestination(
    path: Routes.customers,
    label: 'Customers',
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups_rounded,
    section: 'Business',
    permission: Permissions.customersRead,
  ),
  NavDestination(
    path: Routes.catalog,
    label: 'Catalogue',
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2_rounded,
    section: 'Business',
    permission: Permissions.catalogRead,
  ),
  NavDestination(
    path: Routes.documents,
    label: 'Documents',
    icon: Icons.folder_outlined,
    selectedIcon: Icons.folder_rounded,
    section: 'Business',
    permission: Permissions.documentsRead,
  ),
  NavDestination(
    path: Routes.team,
    label: 'Team',
    icon: Icons.badge_outlined,
    selectedIcon: Icons.badge_rounded,
    section: 'Organization',
    permission: Permissions.membersRead,
  ),
  NavDestination(
    path: Routes.settings,
    label: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
    section: 'Organization',
  ),
];

/// Destinations the given permission set may open.
List<NavDestination> visibleDestinations(Set<String> permissions) => [
      for (final destination in navDestinations)
        if (destination.permission == null || permissions.contains(destination.permission)) destination,
    ];

/// Index of the destination that owns [location] (`/invoices/123` belongs to
/// Invoices), or -1.
int destinationIndexFor(String location, List<NavDestination> destinations) {
  for (var i = 0; i < destinations.length; i++) {
    final path = destinations[i].path;
    if (location == path || location.startsWith('$path/')) return i;
  }
  return -1;
}
