import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_gate.dart';
import '../../../core/design_system/components/buttons.dart';
import '../../../core/design_system/components/feedback.dart';
import '../../../core/design_system/components/fields.dart';
import '../../../core/design_system/components/list_panel.dart';
import '../../../core/design_system/components/nob_card.dart';
import '../../../core/design_system/components/page_scaffold.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/pdf/commercial_pdf.dart';
import '../../../core/pdf/pdf_actions.dart';
import '../../../core/utils/formatters.dart';
import '../../catalog/presentation/line_items_editor.dart';
import '../../customers/application/customer_providers.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../../tenancy/application/tenancy_providers.dart';
import '../../tenancy/domain/organization_party.dart';
import '../../tenancy/domain/permissions.dart';
import '../application/billing_providers.dart';
import '../domain/billing_models.dart';
import 'billing_widgets.dart';

class QuotationDetailScreen extends ConsumerWidget {
  const QuotationDetailScreen({super.key, required this.quotationId});

  final String quotationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void back() => context.go(Routes.quotations);
    return DetailLoader<Quotation>(
      value: ref.watch(quotationProvider(quotationId)),
      title: 'Quotation',
      onBack: back,
      onRetry: () => ref.invalidate(quotationProvider(quotationId)),
      builder: (quotation) => _QuotationView(quotation: quotation, onBack: back),
    );
  }
}

class _QuotationView extends ConsumerStatefulWidget {
  const _QuotationView({required this.quotation, required this.onBack});

  final Quotation quotation;
  final VoidCallback onBack;

  @override
  ConsumerState<_QuotationView> createState() => _QuotationViewState();
}

class _QuotationViewState extends ConsumerState<_QuotationView> {
  bool _busy = false;

  Quotation get _quotation => widget.quotation;

  void _refresh() {
    ref.invalidate(quotationProvider(_quotation.id));
    ref.invalidate(quotationsProvider);
    ref.invalidate(customerQuotationsProvider(_quotation.customerId));
    ref.invalidate(dashboardSummaryProvider);
  }

  Future<void> _setStatus(String status, String done) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(billingRepositoryProvider).setQuotationStatus(_quotation.id, status);
      _refresh();
      if (mounted) showNobSnack(context, done, tone: SnackTone.success);
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _convert() async {
    final confirmed = await confirmAction(
      context,
      title: 'Create an invoice from this quotation?',
      message:
          'A draft invoice is created with the same customer, items and prices. '
          'You can review it before issuing.',
      confirmLabel: 'Create invoice',
    );
    if (!confirmed || _busy) return;
    setState(() => _busy = true);
    try {
      final invoiceId = await ref.read(billingRepositoryProvider).convertQuotation(_quotation.id);
      _refresh();
      ref.invalidate(invoicesProvider);
      if (mounted) context.go('${Routes.invoices}/$invoiceId');
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showFailure(context, error);
    }
  }

  Future<void> _delete() async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete ${_quotation.number}?',
      message: 'The draft quotation is removed for good.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(billingRepositoryProvider).deleteQuotation(_quotation.id);
      ref.invalidate(quotationsProvider);
      if (mounted) widget.onBack();
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showFailure(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quotation = _quotation;
    final organization = ref.watch(activeOrganizationProvider);
    final workspaces = ref.watch(workspacesProvider).value ?? const [];
    final workspaceName = workspaces
        .where((w) => w.id == quotation.workspaceId)
        .map((w) => w.name)
        .firstOrNull;
    final customer = ref.watch(customerProvider(quotation.customerId)).value;
    final canWrite = ref.watch(canProvider(Permissions.quotationsWrite));
    final canInvoice = canWrite && ref.watch(canProvider(Permissions.invoicesWrite));
    final status = quotation.status;
    final issueDate = quotation.issueDate;
    final validUntil = quotation.validUntil;
    final notes = quotation.notes;
    final invoiceId = quotation.convertedInvoiceId;

    CommercialPdfData pdf() => CommercialPdfData(
      title: 'QUOTATION',
      number: quotation.number,
      seller: organization == null
          ? const PdfParty(name: 'N.O Business')
          : sellerParty(organization, workspaceName: workspaceName),
      buyer: PdfParty(
        name: quotation.customerName,
        lines: [?customer?.address, ?customer?.phone, ?customer?.email],
      ),
      meta: [
        if (issueDate != null) ('Date', formatDate(issueDate)),
        if (validUntil != null) ('Valid until', formatDate(validUntil)),
      ],
      items: quotation.items,
      totals: quotation.totals,
      currencyCode: quotation.currencyCode,
      notes: notes,
      footer: organization?.documentFooter,
      brandColorHex: organization?.brandColor,
      stamp: status == 'draft' ? 'DRAFT' : null,
    );

    return PageScaffold(
      title: quotation.number,
      subtitle: quotation.customerName,
      onBack: widget.onBack,
      actions: [
        PdfActions(data: pdf),
        if (quotation.isEditable && canWrite)
          OutlinedButton.icon(
            onPressed: _busy ? null : () => context.go('${Routes.quotations}/${quotation.id}/edit'),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit'),
          ),
        if (status == 'draft' && canWrite)
          PrimaryButton(
            label: 'Mark as sent',
            icon: Icons.send_rounded,
            loading: _busy,
            onPressed: () => _setStatus('sent', 'Quotation marked as sent.'),
          ),
        if (quotation.isConvertible && canInvoice)
          PrimaryButton(
            label: 'Create invoice',
            icon: Icons.description_outlined,
            loading: _busy,
            onPressed: _convert,
          ),
        if (invoiceId != null)
          OutlinedButton.icon(
            onPressed: () => context.go('${Routes.invoices}/$invoiceId'),
            icon: const Icon(Icons.description_outlined, size: 18),
            label: const Text('Open invoice'),
          ),
      ],
      child: TwoPane(
        primary: SectionCard(
          title: 'Items',
          child: RowGroup(
            children: [
              for (final item in quotation.items)
                LineItemRow(item: item, currencyCode: quotation.currencyCode),
            ],
          ),
        ),
        secondary: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NobCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: QuotationStatusBadge(quotation: quotation),
                  ),
                  const SizedBox(height: NobSpace.lg),
                  LabeledValue(label: 'Customer', value: quotation.customerName),
                  if (issueDate != null) ...[
                    const SizedBox(height: NobSpace.md),
                    LabeledValue(label: 'Date', value: formatDate(issueDate)),
                  ],
                  const SizedBox(height: NobSpace.md),
                  LabeledValue(
                    label: 'Valid until',
                    value: validUntil == null ? 'No expiry' : formatDate(validUntil),
                  ),
                  if (notes != null) ...[
                    const SizedBox(height: NobSpace.md),
                    LabeledValue(label: 'Notes', value: notes),
                  ],
                  const SizedBox(height: NobSpace.lg),
                  TotalsSummary(totals: quotation.totals, currencyCode: quotation.currencyCode),
                ],
              ),
            ),
            if (canWrite && status != 'converted') ...[
              const SizedBox(height: NobSpace.lg),
              Wrap(
                spacing: NobSpace.md,
                runSpacing: NobSpace.sm,
                children: [
                  if (status == 'sent') ...[
                    OutlinedButton(
                      onPressed: _busy ? null : () => _setStatus('accepted', 'Marked as accepted.'),
                      child: const Text('Customer accepted'),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : () => _setStatus('declined', 'Marked as declined.'),
                      child: const Text('Customer declined'),
                    ),
                    TextButton(
                      onPressed: _busy ? null : () => _setStatus('draft', 'Moved back to draft.'),
                      child: const Text('Back to draft'),
                    ),
                  ],
                  if (status == 'accepted' || status == 'declined')
                    TextButton(
                      onPressed: _busy ? null : () => _setStatus('sent', 'Reopened as sent.'),
                      child: const Text('Reopen'),
                    ),
                  if (status == 'draft')
                    DangerButton(
                      label: 'Delete',
                      icon: Icons.delete_outline_rounded,
                      onPressed: _busy ? null : _delete,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
