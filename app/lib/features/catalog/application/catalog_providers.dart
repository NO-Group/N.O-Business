import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../tenancy/application/tenancy_providers.dart';
import '../data/catalog_repository.dart';
import '../domain/product.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(ref.watch(supabaseClientProvider)),
);

/// Catalogue of the active organization matching a search query.
final productsProvider = FutureProvider.autoDispose.family<List<Product>, String>((
  ref,
  query,
) async {
  final organizationId = ref.watch(activeOrganizationIdProvider);
  if (organizationId == null) return const [];
  return ref.watch(catalogRepositoryProvider).list(organizationId, query: query);
});

/// Items that can be put on a new sale, quotation or invoice.
final sellableProductsProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  final organizationId = ref.watch(activeOrganizationIdProvider);
  if (organizationId == null) return const [];
  return ref.watch(catalogRepositoryProvider).list(organizationId, activeOnly: true);
});

/// Recent stock movements of one item in the active workspace.
final stockMovementsProvider = FutureProvider.autoDispose.family<List<StockMovement>, String>((
  ref,
  productId,
) async {
  final workspaceId = ref.watch(activeWorkspaceProvider)?.id;
  if (workspaceId == null) return const [];
  return ref
      .watch(catalogRepositoryProvider)
      .movements(productId: productId, workspaceId: workspaceId);
});
