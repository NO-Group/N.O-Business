import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../tenancy/application/tenancy_providers.dart';
import '../data/customer_repository.dart';
import '../domain/customer.dart';

final customerRepositoryProvider = Provider<CustomerRepository>(
  (ref) => CustomerRepository(ref.watch(supabaseClientProvider)),
);

/// Customers of the active organization matching a search query.
final customersProvider = FutureProvider.autoDispose.family<List<Customer>, String>((ref, query) async {
  final organizationId = ref.watch(activeOrganizationIdProvider);
  if (organizationId == null) return const [];
  return ref.watch(customerRepositoryProvider).list(organizationId, query: query);
});

/// One customer of the active organization, or null when it does not exist
/// (or belongs to another organization).
final customerProvider = FutureProvider.autoDispose.family<Customer?, String>((ref, customerId) async {
  final organizationId = ref.watch(activeOrganizationIdProvider);
  if (organizationId == null) return null;
  return ref.watch(customerRepositoryProvider).find(organizationId, customerId);
});
