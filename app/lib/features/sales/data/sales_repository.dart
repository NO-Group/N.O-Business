import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/commerce/line_item.dart';
import '../../../core/errors/guard.dart';
import '../../../core/supabase/query_utils.dart';
import '../../../core/utils/json.dart';
import '../domain/sale.dart';

class SalesRepository {
  const SalesRepository(this._client);

  final SupabaseClient _client;

  static const _columns =
      'id, number, workspace_id, customer_id, status, payment_method, currency_code, '
      'subtotal_minor, discount_minor, tax_minor, total_minor, note, sold_at, voided_at, '
      'customer:customers(name)';
  static const _items =
      'items:sale_items(product_id, description, quantity, unit_price_minor, tax_rate, line_total_minor, position)';

  Future<List<Sale>> list({
    required String organizationId,
    String? workspaceId,
    String? customerId,
  }) => guard('sales.list', () async {
    var request = _client.from('sales').select(_columns).eq('organization_id', organizationId);
    if (workspaceId != null) request = request.eq('workspace_id', workspaceId);
    if (customerId != null) request = request.eq('customer_id', customerId);
    final rows = await request.order('sold_at', ascending: false).limit(listPageSize);
    return rows.map(Sale.fromJson).toList();
  });

  Future<Sale?> find(String organizationId, String saleId) => guard('sales.find', () async {
    final row = await _client
        .from('sales')
        .select('$_columns, $_items')
        .eq('organization_id', organizationId)
        .eq('id', saleId)
        .maybeSingle();
    return row == null ? null : Sale.fromJson(row);
  });

  /// Records a completed sale. The database prices the lines, takes the
  /// stock and assigns the number in one transaction. Returns the sale id.
  Future<String> record({
    required String organizationId,
    required String workspaceId,
    required String? customerId,
    required String paymentMethod,
    required List<DraftLine> lines,
    required int discountMinor,
    String? note,
  }) => guard('sales.record', () async {
    final result = await _client.rpc<dynamic>(
      'record_sale',
      params: {
        'p_org': organizationId,
        'p_workspace_id': workspaceId,
        'p_customer_id': customerId,
        'p_payment_method': paymentMethod,
        'p_items': lines.map((line) => line.toJson()).toList(),
        'p_discount_minor': discountMinor,
        'p_note': note,
      },
    );
    return asString(result);
  });

  Future<void> voidSale(String saleId) => guard('sales.void', () async {
    await _client.rpc<dynamic>('void_sale', params: {'p_sale_id': saleId});
  });
}
