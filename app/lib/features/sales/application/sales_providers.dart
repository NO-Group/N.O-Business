import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../tenancy/application/tenancy_providers.dart';
import '../data/sales_repository.dart';
import '../domain/sale.dart';

final salesRepositoryProvider = Provider<SalesRepository>(
  (ref) => SalesRepository(ref.watch(supabaseClientProvider)),
);

/// Recent sales of the active workspace, newest first.
final salesProvider = FutureProvider.autoDispose<List<Sale>>((ref) async {
  final organizationId = ref.watch(activeOrganizationIdProvider);
  if (organizationId == null) return const [];
  await ref.watch(workspacesProvider.future);
  final workspaceId = ref.watch(activeWorkspaceProvider)?.id;
  if (workspaceId == null) return const [];
  return ref.watch(salesRepositoryProvider).list(organizationId: organizationId, workspaceId: workspaceId);
});

/// Sales made to one customer, across workspaces.
final customerSalesProvider = FutureProvider.autoDispose.family<List<Sale>, String>((ref, customerId) async {
  final organizationId = ref.watch(activeOrganizationIdProvider);
  if (organizationId == null) return const [];
  return ref.watch(salesRepositoryProvider).list(organizationId: organizationId, customerId: customerId);
});

final saleProvider = FutureProvider.autoDispose.family<Sale?, String>((ref, saleId) async {
  final organizationId = ref.watch(activeOrganizationIdProvider);
  if (organizationId == null) return null;
  return ref.watch(salesRepositoryProvider).find(organizationId, saleId);
});
