import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/guard.dart';
import '../../../core/supabase/query_utils.dart';
import '../domain/customer.dart';

class CustomerRepository {
  const CustomerRepository(this._client);

  final SupabaseClient _client;

  static const _columns =
      'id, organization_id, kind, name, email, phone, address, tax_id, notes, created_at';

  Future<List<Customer>> list(String organizationId, {String query = ''}) =>
      guard('customers.list', () async {
        var request = _client
            .from('customers')
            .select(_columns)
            .eq('organization_id', organizationId);
        if (query.trim().isNotEmpty) {
          final pattern = likePattern(query);
          request = request.or('name.ilike.$pattern,email.ilike.$pattern,phone.ilike.$pattern');
        }
        final rows = await request.order('name').limit(listPageSize);
        return rows.map(Customer.fromJson).toList();
      });

  Future<Customer?> find(String organizationId, String customerId) =>
      guard('customers.find', () async {
        final row = await _client
            .from('customers')
            .select(_columns)
            .eq('organization_id', organizationId)
            .eq('id', customerId)
            .maybeSingle();
        return row == null ? null : Customer.fromJson(row);
      });

  Future<Customer> create(String organizationId, CustomerInput input) =>
      guard('customers.create', () async {
        final row = await _client
            .from('customers')
            .insert({...input.toJson(), 'organization_id': organizationId})
            .select(_columns)
            .single();
        return Customer.fromJson(row);
      });

  Future<void> update(String customerId, CustomerInput input) =>
      guard('customers.update', () async {
        final rows = await _client
            .from('customers')
            .update(input.toJson())
            .eq('id', customerId)
            .select('id');
        requireAffected(rows);
      });

  Future<void> delete(String customerId) => guard('customers.delete', () async {
    final rows = await _client.from('customers').delete().eq('id', customerId).select('id');
    requireAffected(rows);
  });
}
