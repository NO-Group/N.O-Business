import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/guard.dart';
import '../../../core/supabase/query_utils.dart';
import '../../../core/utils/json.dart';
import '../domain/product.dart';

class CatalogRepository {
  const CatalogRepository(this._client);

  final SupabaseClient _client;

  static const _columns = 'id, organization_id, kind, name, sku, description, unit, unit_price_minor, '
      'cost_price_minor, tax_rate, track_inventory, reorder_level, is_active, '
      'stock_levels(workspace_id, quantity)';

  Future<List<Product>> list(String organizationId, {String query = '', bool activeOnly = false}) =>
      guard('catalog.list', () async {
        var request = _client.from('products').select(_columns).eq('organization_id', organizationId);
        if (activeOnly) request = request.eq('is_active', true);
        if (query.trim().isNotEmpty) {
          final pattern = likePattern(query);
          request = request.or('name.ilike.$pattern,sku.ilike.$pattern');
        }
        final rows = await request.order('name').limit(listPageSize);
        return rows.map(Product.fromJson).toList();
      });

  Future<void> create(String organizationId, ProductInput input) => guard('catalog.create', () async {
        await _client.from('products').insert({...input.toJson(), 'organization_id': organizationId});
      });

  Future<void> update(String productId, ProductInput input) => guard('catalog.update', () async {
        final rows = await _client.from('products').update(input.toJson()).eq('id', productId).select('id');
        requireAffected(rows);
      });

  Future<void> delete(String productId) => guard('catalog.delete', () async {
        final rows = await _client.from('products').delete().eq('id', productId).select('id');
        requireAffected(rows);
      });

  /// Returns the new quantity on hand.
  Future<double> adjustStock({
    required String workspaceId,
    required String productId,
    required double quantityDelta,
    required String reason,
    String? note,
  }) =>
      guard('catalog.adjust_stock', () async {
        final result = await _client.rpc<dynamic>('adjust_stock', params: {
          'p_workspace_id': workspaceId,
          'p_product_id': productId,
          'p_quantity_delta': quantityDelta,
          'p_reason': reason,
          'p_note': note,
        });
        return asDouble(result);
      });

  Future<List<StockMovement>> movements({required String productId, required String workspaceId}) =>
      guard('catalog.movements', () async {
        final rows = await _client
            .from('stock_movements')
            .select('quantity_delta, reason, workspace_id, note, created_at')
            .eq('product_id', productId)
            .eq('workspace_id', workspaceId)
            .order('created_at', ascending: false)
            .limit(30);
        return rows.map(StockMovement.fromJson).toList();
      });
}
