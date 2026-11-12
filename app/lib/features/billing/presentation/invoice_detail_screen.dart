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
import '../../../core/utils/money.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/presentation/line_items_editor.dart';
import '../../customers/application/customer_providers.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../../tenancy/application/tenancy_providers.dart';
import '../../tenancy/domain/organization_party.dart';
import '../../tenancy/domain/permissions.dart';
import '../application/billing_providers.dart';
import '../domain/billing_models.dart';
import 'billing_widgets.dart';
import 'payment_sheet.dart';

class InvoiceDetailScreen extends ConsumerWidget {
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void back() => context.go(Routes.invoices);
    return DetailLoader<Invoice>(
      value: ref.watch(invoiceProvider(invoiceId)),
      title: 'Invoice',
      onBack: back,
      onRetry: () => ref.invalidate(invoiceProvider(invoiceId)),
      builder: (invoice) => _InvoiceView(invoice: invoice, onBack: back),
    );
  }
}

class _InvoiceView extends ConsumerStatefulWidget {
  const _InvoiceView({required this.invoice, required this.onBack});

  final Invoice invoice;
  final VoidCallback onBack;

  @override
  ConsumerState<_InvoiceView> createState() => _InvoiceViewState();
}

class _InvoiceViewState extends ConsumerState<_InvoiceView> {
  bool _busy = false;

  Invoice get _invoice => widget.invoice;

  void _refresh() {
    ref.invalidate(invoiceProvider(_invoice.id));
    ref.invalidate(invoicesProvider);
    ref.invalidate(customerInvoicesProvider(_invoice.customerId));
    ref.invalidate(dashboardSummaryProvider);
  }

  /// Runs a state-changing action with a busy flag and uniform feedback.
  Future<void> _run(Future<void> Function() action, {required String done}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      _refresh();
      if (mounted) showNobSnack(context, done, tone: SnackTone.success);
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _issue() async {
    final confirmed = await confirmAction(
      context,
      title: 'Issue this invoice?',
      message:
          'It gets its number and today\'s date, tracked stock is taken, and it can no longer '
          'be edited. Use this when the invoice is ready to send.',
      confirmLabel: 'Issue invoice',
    );
    if (!confirmed) return;
    await _run(() async {
      await ref.read(billingRepositoryProvider).issueInvoice(_invoice.id);
      ref.invalidate(productsProvider);
    }, done: 'Invoice issued.');
  }

  Future<void> _void() async {
    final confirmed = await confirmAction(
      context,
      title: 'Void ${_invoice.displayNumber}?',
      message:
          'The invoice stays on record as void, nothing is owed on it and its stock is put '
          'back. This cannot be undone.',
      confirmLabel: 'Void invoice',
      destructive: true,
    );
    if (!confirmed) return;
    await _run(() async {
      await ref.read(billingRepositoryProvider).voidInvoice(_invoice.id);
      ref.invalidate(productsProvider);
    }, done: 'Invoice voided.');
  }

  Future<void> _delete() async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete this draft?',
      message: 'The draft is removed. Nothing has been sent or numbered yet.',
      confirmLabel: 'Delete draft',
      destructive: true,
    );
    if (!confirmed || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(billingRepositoryProvider).deleteInvoiceDraft(_invoice.id);
      ref.invalidate(invoicesProvider);
      ref.invalidate(quotationsProvider);
      if (mounted) widget.onBack();
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showFailure(context, error);
    }
  }

  Future<void> _pay() async {
    final saved = await showPaymentSheet(context, _invoice);
    if (!saved || !mounted) return;
    _refresh();
    showNobSnack(context, 'Payment recorded.', tone: SnackTone.success);
  }

  @override
  Widget build(BuildContext context) {
    final invoice = _invoice;
    final organization = ref.watch(activeOrganizationProvider);
    final workspaces = ref.watch(workspacesProvider).value ?? const [];
    final workspaceName = workspaces
        .where((w) => w.id == invoice.workspaceId)
        .map((w) => w.name)
        .firstOrNull;
    final customer = ref.watch(customerProvider(invoice.customerId)).value;
    final canWrite = ref.watch(canProvider(Permissions.invoicesWrite));
    final canVoid = ref.watch(canProvider(Permissions.invoicesVoid));
    final canPay = ref.watch(canProvider(Permissions.paymentsRecord));
    final currency = invoice.currencyCode;
    final issueDate = invoice.issueDate;
    final dueDate = invoice.dueDate;
    final notes = invoice.notes;

    CommercialPdfData pdf() => CommercialPdfData(
      title: 'INVOICE',
      number: invoice.number,
      seller: organization == null
          ? const PdfParty(name: 'N.O Business')
          : sellerParty(organization, workspaceName: workspaceName),
      buyer: PdfParty(
        name: invoice.customerName,
        lines: [
          ?customer?.address,
          ?customer?.phone,
          ?customer?.email,
          if (customer?.taxId != null) 'Tax ID: ${customer?.taxId}',
        ],
      ),
      meta: [
        if (issueDate != null) ('Issued', formatDate(issueDate)),
        if (dueDate != null) ('Due', formatDate(dueDate)),
      ],
      items: invoice.items,
      totals: invoice.totals,
      currencyCode: currency,
      afterTotal: [
        if (invoice.amountPaidMinor > 0) ('Paid', invoice.amountPaidMinor),
        if (!invoice.isDraft && invoice.status != 'void') ('Balance due', invoice.balanceMinor),
      ],
      notes: notes,
      footer: organization?.documentFooter,
      brandColorHex: organization?.brandColor,
      stamp: switch (invoice.status) {
        'draft' => 'DRAFT',
        'void' => 'VOID',
        'paid' => 'PAID',
        _ => null,
      },
    );

    return PageScaffold(
      title: invoice.displayNumber,
      subtitle: invoice.customerName,
      onBack: widget.onBack,
      actions: [
        PdfActions(data: pdf),
        if (invoice.isDraft && canWrite) ...[
          OutlinedButton.icon(
            onPressed: _busy ? null : () => context.go('${Routes.invoices}/${invoice.id}/edit'),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit'),
          ),
          PrimaryButton(
            label: 'Issue invoice',
            icon: Icons.send_rounded,
            onPressed: _issue,
            loading: _busy,
          ),
        ],
        if (invoice.isOpen && canPay)
          PrimaryButton(
            label: 'Record payment',
            icon: Icons.payments_outlined,
            onPressed: _pay,
            loading: _busy,
          ),
      ],
      child: TwoPane(
        primary: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionCard(
              title: 'Items',
              child: RowGroup(
                children: [
                  for (final item in invoice.items) LineItemRow(item: item, currencyCode: currency),
                ],
              ),
            ),
            if (invoice.payments.isNotEmpty) ...[
              const SizedBox(height: NobSpace.lg),
              SectionCard(
                title: 'Payments',
                child: RowGroup(
                  children: [
                    for (final payment in invoice.payments)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: NobSpace.md),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(humanize(payment.method), style: NobText.subtitle),
                                  Text(
                                    [
                                      if (payment.paidAt != null) formatDateTime(payment.paidAt!),
                                      ?payment.reference,
                                    ].join(' · '),
                                    style: NobText.bodySmall.copyWith(
                                      color: NobColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              Money.format(payment.amountMinor, currency),
                              style: NobText.numeric.copyWith(color: NobColors.success),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
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
                    child: InvoiceStatusBadge(invoice: invoice),
                  ),
                  const SizedBox(height: NobSpace.lg),
                  LabeledValue(label: 'Customer', value: invoice.customerName),
                  if (issueDate != null) ...[
                    const SizedBox(height: NobSpace.md),
                    LabeledValue(label: 'Issued', value: formatDate(issueDate)),
                  ],
                  const SizedBox(height: NobSpace.md),
                  LabeledValue(
                    label: 'Due',
                    value: dueDate == null ? 'No due date' : formatDate(dueDate),
                  ),
                  if (workspaceName != null) ...[
                    const SizedBox(height: NobSpace.md),
                    LabeledValue(label: 'Workspace', value: workspaceName),
                  ],
                  if (notes != null) ...[
                    const SizedBox(height: NobSpace.md),
                    LabeledValue(label: 'Notes', value: notes),
                  ],
                  const SizedBox(height: NobSpace.lg),
                  TotalsSummary(
                    totals: invoice.totals,
                    currencyCode: currency,
                    extra: [
                      if (invoice.amountPaidMinor > 0) ('Paid', invoice.amountPaidMinor),
                      if (invoice.isOpen || invoice.status == 'paid')
                        ('Balance due', invoice.balanceMinor),
                    ],
                  ),
                ],
              ),
            ),
            if (invoice.isDraft && canWrite || invoice.status == 'issued' && canVoid) ...[
              const SizedBox(height: NobSpace.lg),
              Align(
                alignment: Alignment.centerLeft,
                child: invoice.isDraft
                    ? DangerButton(
                        label: 'Delete draft',
                        icon: Icons.delete_outline_rounded,
                        onPressed: _busy ? null : _delete,
                      )
                    : DangerButton(
                        label: 'Void invoice',
                        icon: Icons.block_rounded,
                        // The database refuses to void once money has been received.
                        onPressed: _busy || invoice.amountPaidMinor > 0 ? null : _void,
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
