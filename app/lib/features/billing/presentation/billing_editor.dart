import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_gate.dart';
import '../../../core/commerce/line_item.dart';
import '../../../core/design_system/components/buttons.dart';
import '../../../core/design_system/components/fields.dart';
import '../../../core/design_system/components/nob_card.dart';
import '../../../core/design_system/components/page_scaffold.dart';
import '../../../core/design_system/components/state_views.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/validators.dart';
import '../../catalog/presentation/line_items_editor.dart';
import '../../customers/application/customer_providers.dart';
import '../../customers/domain/customer.dart';
import '../../customers/presentation/customer_picker.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../../tenancy/application/tenancy_providers.dart';
import '../../tenancy/domain/permissions.dart';
import '../application/billing_providers.dart';
import '../domain/billing_models.dart';

/// Create or edit a draft invoice.
class InvoiceEditorScreen extends ConsumerWidget {
  const InvoiceEditorScreen({super.key, this.invoiceId, this.customerId});

  /// Null when creating.
  final String? invoiceId;

  /// Customer to preselect on a new invoice.
  final String? customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = invoiceId;
    if (!ref.watch(canProvider(Permissions.invoicesWrite))) {
      return PageScaffold(
        title: 'Invoice',
        onBack: () => context.go(Routes.invoices),
        scrollable: false,
        child: const NoAccessState(),
      );
    }
    if (id == null) {
      return _BillingEditor(kind: _Kind.invoice, presetCustomerId: customerId);
    }
    void back() => context.go('${Routes.invoices}/$id');
    return DetailLoader<Invoice>(
      value: ref.watch(invoiceProvider(id)),
      title: 'Invoice',
      onBack: back,
      onRetry: () => ref.invalidate(invoiceProvider(id)),
      builder: (invoice) => _BillingEditor(
        kind: _Kind.invoice,
        recordId: invoice.id,
        initial: _Initial(
          customerId: invoice.customerId,
          customerName: invoice.customerName,
          lines: invoice.items.map(DraftLine.fromItem).toList(),
          discountMinor: invoice.totals.discountMinor,
          date: invoice.dueDate,
          notes: invoice.notes,
          editable: invoice.isDraft,
        ),
      ),
    );
  }
}

/// Create or edit a quotation.
class QuotationEditorScreen extends ConsumerWidget {
  const QuotationEditorScreen({super.key, this.quotationId, this.customerId});

  /// Null when creating.
  final String? quotationId;

  /// Customer to preselect on a new quotation.
  final String? customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = quotationId;
    if (!ref.watch(canProvider(Permissions.quotationsWrite))) {
      return PageScaffold(
        title: 'Quotation',
        onBack: () => context.go(Routes.quotations),
        scrollable: false,
        child: const NoAccessState(),
      );
    }
    if (id == null) {
      return _BillingEditor(kind: _Kind.quotation, presetCustomerId: customerId);
    }
    void back() => context.go('${Routes.quotations}/$id');
    return DetailLoader<Quotation>(
      value: ref.watch(quotationProvider(id)),
      title: 'Quotation',
      onBack: back,
      onRetry: () => ref.invalidate(quotationProvider(id)),
      builder: (quotation) => _BillingEditor(
        kind: _Kind.quotation,
        recordId: quotation.id,
        initial: _Initial(
          customerId: quotation.customerId,
          customerName: quotation.customerName,
          lines: quotation.items.map(DraftLine.fromItem).toList(),
          discountMinor: quotation.totals.discountMinor,
          date: quotation.validUntil,
          notes: quotation.notes,
          editable: quotation.isEditable,
        ),
      ),
    );
  }
}

enum _Kind {
  invoice('invoice', 'Due date', Routes.invoices),
  quotation('quotation', 'Valid until', Routes.quotations);

  const _Kind(this.noun, this.dateLabel, this.route);

  final String noun;
  final String dateLabel;
  final String route;
}

class _Initial {
  const _Initial({
    required this.customerId,
    required this.customerName,
    required this.lines,
    required this.discountMinor,
    required this.editable,
    this.date,
    this.notes,
  });

  final String customerId;
  final String customerName;
  final List<DraftLine> lines;
  final int discountMinor;
  final DateTime? date;
  final String? notes;

  /// False when the record has moved past the state in which it may change.
  final bool editable;
}

class _BillingEditor extends ConsumerStatefulWidget {
  const _BillingEditor({required this.kind, this.recordId, this.initial, this.presetCustomerId});

  final _Kind kind;
  final String? recordId;
  final _Initial? initial;
  final String? presetCustomerId;

  @override
  ConsumerState<_BillingEditor> createState() => _BillingEditorState();
}

class _BillingEditorState extends ConsumerState<_BillingEditor> {
  late final String _currency = ref.read(activeOrganizationProvider)?.currencyCode ?? 'USD';
  late final _discount = TextEditingController(
    text: (widget.initial?.discountMinor ?? 0) > 0
        ? Money.toInput(widget.initial!.discountMinor, _currency)
        : '',
  );
  late final _notes = TextEditingController(text: widget.initial?.notes);
  late List<DraftLine> _lines = widget.initial?.lines ?? const [];
  late String? _customerId = widget.initial?.customerId;
  late String? _customerName = widget.initial?.customerName;
  late DateTime? _date = widget.initial?.date;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final preset = widget.presetCustomerId;
    final organizationId = ref.read(activeOrganizationIdProvider);
    if (preset != null && organizationId != null && widget.initial == null) {
      // Looked up inside the active organization, so an id from another
      // organization simply does not resolve.
      ref.read(customerRepositoryProvider).find(organizationId, preset).then((customer) {
        if (customer != null && mounted && _customerId == null) {
          setState(() {
            _customerId = customer.id;
            _customerName = customer.name;
          });
        }
      }).ignore();
    }
  }

  @override
  void dispose() {
    _discount.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _back() {
    final id = widget.recordId;
    context.go(id == null ? widget.kind.route : '${widget.kind.route}/$id');
  }

  Future<void> _pickCustomer() async {
    final Customer? picked = await showCustomerPicker(context);
    if (picked == null || !mounted) return;
    setState(() {
      _customerId = picked.id;
      _customerName = picked.name;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: current != null && !current.isBefore(today) ? current : today,
      firstDate: today,
      lastDate: DateTime(today.year + 5, today.month, today.day),
      helpText: widget.kind.dateLabel,
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    final organizationId = ref.read(activeOrganizationIdProvider);
    final workspaceId = ref.read(activeWorkspaceProvider)?.id;
    final customerId = _customerId;
    if (organizationId == null || workspaceId == null) return;
    final discount = _discount.text.trim().isEmpty ? 0 : Money.parse(_discount.text, _currency);
    final String? problem = customerId == null
        ? 'Choose a customer.'
        : _lines.isEmpty
        ? 'Add at least one item.'
        : discount == null
        ? 'Enter the discount as an amount, for example 500.00.'
        : null;
    if (problem != null || customerId == null || discount == null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final draft = BillingDraft(
      customerId: customerId,
      lines: _lines,
      discountMinor: discount,
      date: _date,
      notes: nullIfBlank(_notes.text),
    );
    try {
      final repository = ref.read(billingRepositoryProvider);
      final String id;
      if (widget.kind == _Kind.invoice) {
        id = await repository.saveInvoice(
          organizationId: organizationId,
          workspaceId: workspaceId,
          draft: draft,
          invoiceId: widget.recordId,
        );
        ref.invalidate(invoiceProvider(id));
        ref.invalidate(invoicesProvider);
        ref.invalidate(customerInvoicesProvider(customerId));
      } else {
        id = await repository.saveQuotation(
          organizationId: organizationId,
          workspaceId: workspaceId,
          draft: draft,
          quotationId: widget.recordId,
        );
        ref.invalidate(quotationProvider(id));
        ref.invalidate(quotationsProvider);
        ref.invalidate(customerQuotationsProvider(customerId));
      }
      ref.invalidate(dashboardSummaryProvider);
      if (mounted) context.go('${widget.kind.route}/$id');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = AppFailure.from(error).message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final isNew = widget.recordId == null;
    final title = '${isNew ? 'New' : 'Edit'} ${kind.noun}';

    if (widget.initial?.editable == false) {
      return PageScaffold(
        title: title,
        onBack: _back,
        scrollable: false,
        child: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'This ${kind.noun} can no longer be edited',
          message: kind == _Kind.invoice
              ? 'An issued invoice is a financial record. Void it and raise a new one if it is wrong.'
              : 'Only draft or sent quotations can change.',
        ),
      );
    }

    final organization = ref.watch(activeOrganizationProvider);
    final workspace = ref.watch(activeWorkspaceProvider);
    final totals = DocumentTotals.preview(
      _lines,
      discountMinor: Money.parse(_discount.text, _currency) ?? 0,
    );
    final date = _date;
    final error = _error;
    final customerId = _customerId;

    return PageScaffold(
      title: title,
      subtitle: workspace == null ? null : 'From ${workspace.name} · amounts in $_currency',
      onBack: _back,
      child: TwoPane(
        primary: SectionCard(
          title: 'Items',
          child: LineItemsEditor(
            lines: _lines,
            onChanged: (lines) => setState(() => _lines = lines),
            currencyCode: _currency,
            defaultTaxRate: organization?.defaultTaxRate ?? 0,
          ),
        ),
        secondary: NobCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Details', style: NobText.title),
              const SizedBox(height: NobSpace.lg),
              CustomerField(
                customer: customerId == null
                    ? null
                    : Customer(
                        id: customerId,
                        organizationId: organization?.id ?? '',
                        kind: 'individual',
                        name: _customerName ?? 'Customer',
                      ),
                onPick: _pickCustomer,
              ),
              const SizedBox(height: NobSpace.lg),
              InkWell(
                onTap: _pickDate,
                borderRadius: NobRadius.medium,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: '${kind.dateLabel} (optional)',
                    suffixIcon: date == null
                        ? const Icon(Icons.event_outlined)
                        : IconButton(
                            tooltip: 'Clear date',
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => setState(() => _date = null),
                          ),
                  ),
                  isEmpty: date == null,
                  child: date == null ? null : Text(formatDate(date), style: NobText.body),
                ),
              ),
              const SizedBox(height: NobSpace.lg),
              TextField(
                controller: _discount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Discount ($_currency, optional)'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: NobSpace.lg),
              TextField(
                controller: _notes,
                maxLength: 2000,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  helperText: 'Printed on the document.',
                  counterText: '',
                ),
              ),
              const SizedBox(height: NobSpace.lg),
              TotalsSummary(totals: totals, currencyCode: _currency),
              if (error != null) ...[const SizedBox(height: NobSpace.lg), FormMessage(error)],
              const SizedBox(height: NobSpace.lg),
              PrimaryButton(
                label: kind == _Kind.invoice ? 'Save draft' : 'Save quotation',
                icon: Icons.check_rounded,
                expanded: true,
                loading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
