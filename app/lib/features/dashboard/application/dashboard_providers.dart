import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../tenancy/application/tenancy_providers.dart';
import '../../tenancy/domain/permissions.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard_summary.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(ref.watch(supabaseClientProvider)),
);

/// What the dashboard is looking at.
class DashboardFilter {
  const DashboardFilter({this.days = 30, this.allWorkspaces = false});

  final int days;
  final bool allWorkspaces;

  DashboardFilter copyWith({int? days, bool? allWorkspaces}) =>
      DashboardFilter(days: days ?? this.days, allWorkspaces: allWorkspaces ?? this.allWorkspaces);

  @override
  bool operator ==(Object other) =>
      other is DashboardFilter && other.days == days && other.allWorkspaces == allWorkspaces;

  @override
  int get hashCode => Object.hash(days, allWorkspaces);
}

class DashboardFilterController extends Notifier<DashboardFilter> {
  @override
  DashboardFilter build() => const DashboardFilter();

  void setDays(int days) => state = state.copyWith(days: days);

  void setAllWorkspaces(bool value) => state = state.copyWith(allWorkspaces: value);
}

final dashboardFilterProvider = NotifierProvider<DashboardFilterController, DashboardFilter>(
  DashboardFilterController.new,
);

/// Summary for the active organization and filter. Null when the active
/// role may not view reports (the database would refuse the call anyway).
final dashboardSummaryProvider = FutureProvider<DashboardSummary?>((ref) async {
  final organizationId = ref.watch(activeOrganizationIdProvider);
  if (organizationId == null || !ref.watch(canProvider(Permissions.reportsView))) return null;
  final filter = ref.watch(dashboardFilterProvider);
  String? workspaceId;
  if (!filter.allWorkspaces) {
    // The active workspace is only known once the workspace list has loaded.
    await ref.watch(workspacesProvider.future);
    workspaceId = ref.watch(activeWorkspaceProvider)?.id;
  }
  return ref
      .watch(dashboardRepositoryProvider)
      .summary(organizationId: organizationId, workspaceId: workspaceId, days: filter.days);
});
