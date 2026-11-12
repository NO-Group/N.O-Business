import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../tenancy/application/tenancy_providers.dart';
import '../data/team_repository.dart';
import '../domain/team_models.dart';

final teamRepositoryProvider = Provider<TeamRepository>(
  (ref) => TeamRepository(ref.watch(supabaseClientProvider)),
);

final membersProvider = FutureProvider.autoDispose<List<Member>>((ref) async {
  final organizationId = ref.watch(activeOrganizationIdProvider);
  if (organizationId == null) return const [];
  return ref.watch(teamRepositoryProvider).members(organizationId);
});

final invitationsProvider = FutureProvider.autoDispose<List<Invitation>>((ref) async {
  final organizationId = ref.watch(activeOrganizationIdProvider);
  if (organizationId == null) return const [];
  return ref.watch(teamRepositoryProvider).pendingInvitations(organizationId);
});

final rolesProvider = FutureProvider.autoDispose<List<Role>>((ref) async {
  final organizationId = ref.watch(activeOrganizationIdProvider);
  if (organizationId == null) return const [];
  return ref.watch(teamRepositoryProvider).roles(organizationId);
});

/// The permission catalogue is global reference data; it is loaded once.
final permissionCatalogueProvider = FutureProvider<List<PermissionInfo>>(
  (ref) => ref.watch(teamRepositoryProvider).permissionCatalogue(),
);

final auditTrailProvider = FutureProvider.autoDispose<List<AuditEntry>>((ref) async {
  final organizationId = ref.watch(activeOrganizationIdProvider);
  if (organizationId == null) return const [];
  return ref.watch(teamRepositoryProvider).auditTrail(organizationId);
});
