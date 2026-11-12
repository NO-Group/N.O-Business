import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../tenancy/application/tenancy_providers.dart';
import '../data/billing_repository.dart';
import '../domain/billing_models.dart';

final billingRepositoryProvider = Provider<BillingRepository>(
  (ref) => BillingRepository(ref.watch(supabaseClientProvider)),
);

/// Resolves the active workspace id once the workspace list has loaded.
Future<String?> _activeWorkspaceId(Ref ref) async {
  await ref.watch(workspacesProvider.future);
  return ref.watch(activeWorkspaceProvider)?.id;
}

/// Quotations of the active workspace, newest first.
final quotationsProvider = FutureProvider.autoDispose<List<Quotation>>((ref) async {
  final organizationId = ref.watch(activeOrganizationIdProvider);
  if (organizationId == null) return const [];
  final workspaceId = await _activeWorkspaceId(ref);
  if (workspaceId == null) return const [];
  return ref
      .watch(billingRepositoryProvider)
      .listQuotations(organizationId: organizationId, workspaceId: workspaceId);
});

final quotationProvider = FutureProvider.autoDispose.family<Quotation?, String>((ref, quotationId) async {
  final organizationId = ref.watch(activeOrganizationIdProvider);
  if (organizationId == null) return null;
  return ref.watch(billingRepositoryProvider).findQuotation(organizationId, quotationId);
});

/// Invoices of the active workspace, newest first.
final invoicesProvider = FutureProvider.autoDispose<List<Invoice>>((ref) async {
  final organizationId = ref.watch(activeOrganizationIdProvider);
  if (organizationId == null) return const [];
  final workspaceId = await _activeWorkspaceId(ref);
  if (workspaceId == null) return const [];
  return ref
      .watch(billingRepositoryProvider)
      .listInvoices(organizationId: organizationId, workspaceId: workspaceId);
});

final invoiceProvider = FutureProvider.autoDispose.family<Invoice?, String>((ref, invoiceId) async {
  final organizationId = ref.watch(activeOrganizationIdProvider);
  if (organizationId == null) return null;
  return ref.watch(billingRepositoryProvider).findInvoice(organizationId, invoiceId);
});

/// Invoices raised for one customer, across workspaces.
final customerInvoicesProvider =
    FutureProvider.autoDispose.family<List<Invoice>, String>((ref, customerId) async {
  final organizationId = ref.watch(activeOrganizationIdProvider);
  if (organizationId == null) return const [];
  return ref
      .watch(billingRepositoryProvider)
      .listInvoices(organizationId: organizationId, customerId: customerId);
});

/// Quotations prepared for one customer, across workspaces.
final customerQuotationsProvider =
    FutureProvider.autoDispose.family<List<Quotation>, String>((ref, customerId) async {
  final organizationId = ref.watch(activeOrganizationIdProvider);
  if (organizationId == null) return const [];
  return ref
      .watch(billingRepositoryProvider)
      .listQuotations(organizationId: organizationId, customerId: customerId);
});
