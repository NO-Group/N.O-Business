import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/guard.dart';
import '../../../core/supabase/query_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';
import '../domain/billing_models.dart';

class BillingRepository {
  const BillingRepository(this._client);

  final SupabaseClient _client;

  static const _lineColumns =
      'product_id, description, quantity, unit_price_minor, tax_rate, line_total_minor, position';
  static const _quotationColumns = 'id, number, workspace_id, customer_id, status, issue_date, valid_until, '
      'currency_code, subtotal_minor, discount_minor, tax_minor, total_minor, notes, '
      'converted_invoice_id, customer:customers(name)';
  static const _invoiceColumns = 'id, number, workspace_id, customer_id, quotation_id, status, issue_date, '
      'due_date, currency_code, subtotal_minor, discount_minor, tax_minor, total_minor, '
      'amount_paid_minor, notes, customer:customers(name)';

  // ---- Quotations --------------------------------------------------------

  Future<List<Quotation>> listQuotations({
    required String organizationId,
    String? workspaceId,
    String? customerId,
  }) =>
      guard('quotations.list', () async {
        var request =
            _client.from('quotations').select(_quotationColumns).eq('organization_id', organizationId);
        if (workspaceId != null) request = request.eq('workspace_id', workspaceId);
        if (customerId != null) request = request.eq('customer_id', customerId);
        final rows = await request.order('created_at', ascending: false).limit(listPageSize);
        return rows.map(Quotation.fromJson).toList();
      });

  Future<Quotation?> findQuotation(String organizationId, String quotationId) =>
      guard('quotations.find', () async {
        final row = await _client
            .from('quotations')
            .select('$_quotationColumns, items:quotation_items($_lineColumns)')
            .eq('organization_id', organizationId)
            .eq('id', quotationId)
            .maybeSingle();
        return row == null ? null : Quotation.fromJson(row);
      });

  /// Creates ([quotationId] null) or replaces a quotation. Returns its id.
  Future<String> saveQuotation({
    required String organizationId,
    required String workspaceId,
    required BillingDraft draft,
    String? quotationId,
  }) =>
      guard('quotations.save', () async {
        final date = draft.date;
        final result = await _client.rpc<dynamic>('save_quotation', params: {
          'p_org': organizationId,
          'p_quotation_id': quotationId,
          'p_workspace_id': workspaceId,
          'p_customer_id': draft.customerId,
          'p_valid_until': date == null ? null : toIsoDate(date),
          'p_items': draft.lines.map((line) => line.toJson()).toList(),
          'p_discount_minor': draft.discountMinor,
          'p_notes': draft.notes,
        });
        return asString(result);
      });

  Future<void> setQuotationStatus(String quotationId, String status) =>
      guard('quotations.status', () async {
        await _client.rpc<dynamic>(
          'set_quotation_status',
          params: {'p_quotation_id': quotationId, 'p_status': status},
        );
      });

  Future<void> deleteQuotation(String quotationId) => guard('quotations.delete', () async {
        await _client.rpc<dynamic>('delete_quotation', params: {'p_quotation_id': quotationId});
      });

  /// Returns the id of the draft invoice created from the quotation.
  Future<String> convertQuotation(String quotationId) => guard('quotations.convert', () async {
        final result = await _client.rpc<dynamic>(
          'convert_quotation_to_invoice',
          params: {'p_quotation_id': quotationId},
        );
        return asString(result);
      });

  // ---- Invoices ----------------------------------------------------------

  Future<List<Invoice>> listInvoices({
    required String organizationId,
    String? workspaceId,
    String? customerId,
  }) =>
      guard('invoices.list', () async {
        var request = _client.from('invoices').select(_invoiceColumns).eq('organization_id', organizationId);
        if (workspaceId != null) request = request.eq('workspace_id', workspaceId);
        if (customerId != null) request = request.eq('customer_id', customerId);
        final rows = await request.order('created_at', ascending: false).limit(listPageSize);
        return rows.map(Invoice.fromJson).toList();
      });

  Future<Invoice?> findInvoice(String organizationId, String invoiceId) => guard('invoices.find', () async {
        final row = await _client
            .from('invoices')
            .select(
              '$_invoiceColumns, items:invoice_items($_lineColumns), '
              'payments(id, amount_minor, method, reference, paid_at)',
            )
            .eq('organization_id', organizationId)
            .eq('id', invoiceId)
            .maybeSingle();
        return row == null ? null : Invoice.fromJson(row);
      });

  /// Creates ([invoiceId] null) or replaces a draft invoice. Returns its id.
  Future<String> saveInvoice({
    required String organizationId,
    required String workspaceId,
    required BillingDraft draft,
    String? invoiceId,
  }) =>
      guard('invoices.save', () async {
        final date = draft.date;
        final result = await _client.rpc<dynamic>('save_invoice', params: {
          'p_org': organizationId,
          'p_invoice_id': invoiceId,
          'p_workspace_id': workspaceId,
          'p_customer_id': draft.customerId,
          'p_due_date': date == null ? null : toIsoDate(date),
          'p_items': draft.lines.map((line) => line.toJson()).toList(),
          'p_discount_minor': draft.discountMinor,
          'p_notes': draft.notes,
        });
        return asString(result);
      });

  Future<void> deleteInvoiceDraft(String invoiceId) => guard('invoices.delete', () async {
        await _client.rpc<dynamic>('delete_invoice_draft', params: {'p_invoice_id': invoiceId});
      });

  /// Issues a draft: assigns the number and takes tracked stock. Returns the
  /// invoice number.
  Future<String> issueInvoice(String invoiceId) => guard('invoices.issue', () async {
        final result = await _client.rpc<dynamic>('issue_invoice', params: {'p_invoice_id': invoiceId});
        return asString(result);
      });

  Future<void> recordPayment({
    required String invoiceId,
    required int amountMinor,
    required String method,
    String? reference,
  }) =>
      guard('invoices.payment', () async {
        await _client.rpc<dynamic>('record_invoice_payment', params: {
          'p_invoice_id': invoiceId,
          'p_amount_minor': amountMinor,
          'p_method': method,
          'p_reference': reference,
        });
      });

  Future<void> voidInvoice(String invoiceId) => guard('invoices.void', () async {
        await _client.rpc<dynamic>('void_invoice', params: {'p_invoice_id': invoiceId});
      });
}
