import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_gate.dart';
import '../../../core/design_system/components/list_panel.dart';
import '../../../core/design_system/components/status_badge.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/money.dart';
import '../domain/billing_models.dart';

class InvoiceStatusBadge extends StatelessWidget {
  const InvoiceStatusBadge({super.key, required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    if (invoice.isOverdue(DateTime.now())) {
      return const StatusBadge(label: 'Overdue', tone: BadgeTone.danger);
    }
    return switch (invoice.status) {
      'draft' => const StatusBadge(label: 'Draft'),
      'issued' => const StatusBadge(label: 'Awaiting payment', tone: BadgeTone.info),
      'partially_paid' => const StatusBadge(label: 'Part paid', tone: BadgeTone.warning),
      'paid' => const StatusBadge(label: 'Paid', tone: BadgeTone.success),
      'void' => const StatusBadge(label: 'Void', tone: BadgeTone.danger),
      _ => StatusBadge(label: humanize(invoice.status)),
    };
  }
}

class QuotationStatusBadge extends StatelessWidget {
  const QuotationStatusBadge({super.key, required this.quotation});

  final Quotation quotation;

  @override
  Widget build(BuildContext context) {
    if (quotation.isExpired(DateTime.now())) {
      return const StatusBadge(label: 'Expired', tone: BadgeTone.warning);
    }
    return switch (quotation.status) {
      'draft' => const StatusBadge(label: 'Draft'),
      'sent' => const StatusBadge(label: 'Sent', tone: BadgeTone.info),
      'accepted' => const StatusBadge(label: 'Accepted', tone: BadgeTone.success),
      'declined' => const StatusBadge(label: 'Declined', tone: BadgeTone.danger),
      'converted' => const StatusBadge(label: 'Invoiced', tone: BadgeTone.accent),
      _ => StatusBadge(label: humanize(quotation.status)),
    };
  }
}

/// One invoice in a list. Also used on the customer page.
class InvoiceRow extends StatelessWidget {
  const InvoiceRow({super.key, required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final due = invoice.dueDate;
    return ListRow(
      leading: const RowIcon(Icons.description_outlined, color: NobColors.cobalt),
      title: invoice.displayNumber,
      subtitle: [
        invoice.customerName,
        if (due != null) 'Due ${formatDate(due)}',
        if (invoice.isOpen && invoice.amountPaidMinor > 0)
          '${Money.format(invoice.balanceMinor, invoice.currencyCode)} outstanding',
      ].join(' · '),
      trailing: TrailingAmount(
        amount: Money.format(invoice.totals.totalMinor, invoice.currencyCode),
        below: InvoiceStatusBadge(invoice: invoice),
      ),
      onTap: () => context.go('${Routes.invoices}/${invoice.id}'),
    );
  }
}

/// One quotation in a list. Also used on the customer page.
class QuotationRow extends StatelessWidget {
  const QuotationRow({super.key, required this.quotation});

  final Quotation quotation;

  @override
  Widget build(BuildContext context) {
    final until = quotation.validUntil;
    return ListRow(
      leading: const RowIcon(Icons.request_quote_outlined, color: NobColors.violet),
      title: quotation.number,
      subtitle: [
        quotation.customerName,
        if (until != null) 'Valid until ${formatDate(until)}',
      ].join(' · '),
      trailing: TrailingAmount(
        amount: Money.format(quotation.totals.totalMinor, quotation.currencyCode),
        below: QuotationStatusBadge(quotation: quotation),
      ),
      onTap: () => context.go('${Routes.quotations}/${quotation.id}'),
    );
  }
}
