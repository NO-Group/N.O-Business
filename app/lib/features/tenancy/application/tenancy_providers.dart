import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../data/tenancy_repository.dart';
import '../domain/models.dart';

final tenancyRepositoryProvider = Provider<TenancyRepository>(
  (ref) => TenancyRepository(ref.watch(supabaseClientProvider)),
);

/// Profile, memberships (with permissions) and pending invitations of the
/// signed-in user. Null while signed out.
final myContextProvider = FutureProvider<MyContext?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(tenancyRepositoryProvider).fetchContext();
});

/// Which organization the user chose to work in on this device.
class SelectedOrganization extends Notifier<String?> {
  @override
  String? build() => ref.watch(appPreferencesProvider).lastOrganizationId;

  void select(String organizationId) {
    state = organizationId;
    unawaited(ref.read(appPreferencesProvider).setLastOrganizationId(organizationId));
  }
}

final selectedOrganizationProvider = NotifierProvider<SelectedOrganization, String?>(
  SelectedOrganization.new,
);

/// The membership the app is currently operating under: the chosen
/// organization if the user still belongs to it, otherwise their first one.
final activeMembershipProvider = Provider<OrgMembership?>((ref) {
  final memberships = ref.watch(myContextProvider).value?.memberships ?? const <OrgMembership>[];
  if (memberships.isEmpty) return null;
  final selected = ref.watch(selectedOrganizationProvider);
  for (final membership in memberships) {
    if (membership.organization.id == selected) return membership;
  }
  return memberships.first;
});

/// Id of the active organization. Every tenant-scoped provider watches this,
/// so switching organization rebuilds all of them and nothing leaks across.
final activeOrganizationIdProvider = Provider<String?>(
  (ref) => ref.watch(activeMembershipProvider.select((membership) => membership?.organization.id)),
);

final activeOrganizationProvider = Provider<Organization?>(
  (ref) => ref.watch(activeMembershipProvider)?.organization,
);

/// Permissions of the active membership. For presentation only; the
/// database enforces the same keys.
final permissionsProvider = Provider<Set<String>>(
  (ref) => ref.watch(activeMembershipProvider)?.permissions ?? const <String>{},
);

/// Whether the active membership holds [permission].
final canProvider = Provider.family<bool, String>(
  (ref, permission) => ref.watch(permissionsProvider).contains(permission),
);

/// All workspaces of the active organization, archived ones included.
final workspacesProvider = FutureProvider<List<Workspace>>((ref) async {
  final organizationId = ref.watch(activeOrganizationIdProvider);
  if (organizationId == null) return const [];
  return ref.watch(tenancyRepositoryProvider).listWorkspaces(organizationId);
});

/// Which workspace the user chose for the active organization.
class SelectedWorkspace extends Notifier<String?> {
  @override
  String? build() {
    final organizationId = ref.watch(activeOrganizationIdProvider);
    if (organizationId == null) return null;
    return ref.watch(appPreferencesProvider).lastWorkspaceId(organizationId);
  }

  void select(String workspaceId) {
    final organizationId = ref.read(activeOrganizationIdProvider);
    if (organizationId == null) return;
    state = workspaceId;
    unawaited(ref.read(appPreferencesProvider).setLastWorkspaceId(organizationId, workspaceId));
  }
}

final selectedWorkspaceProvider = NotifierProvider<SelectedWorkspace, String?>(
  SelectedWorkspace.new,
);

/// The workspace sales, stock and billing screens operate in: the chosen one
/// if it is still usable, else the organization's default, else the first.
final activeWorkspaceProvider = Provider<Workspace?>((ref) {
  final all = ref.watch(workspacesProvider).value ?? const <Workspace>[];
  final usable = all.where((workspace) => !workspace.isArchived).toList();
  if (usable.isEmpty) return null;
  final selected = ref.watch(selectedWorkspaceProvider);
  for (final workspace in usable) {
    if (workspace.id == selected) return workspace;
  }
  for (final workspace in usable) {
    if (workspace.isDefault) return workspace;
  }
  return usable.first;
});
