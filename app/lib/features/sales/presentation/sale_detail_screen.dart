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
import '../../../core/design_system/components/status_badge.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/pdf/commercial_pdf.dart';
import '../../../core/pdf/pdf_actions.dart';
import '../../../core/utils/formatters.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/presentation/line_items_editor.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../../tenancy/application/tenancy_providers.dart';
import '../../tenancy/domain/organization_party.dart';
import '../../tenancy/domain/permissions.dart';
import '../application/sales_providers.dart';
import '../domain/sale.dart';

class SaleDetailScreen extends ConsumerWidget {
  const SaleDetailScreen({super.key, required this.saleId});

  final String saleId;

  Future<void> _void(BuildContext context, WidgetRef ref, Sale sale) async {
    final confirmed = await confirmAction(
      context,
      title: 'Void ${sale.number}?',
      message: 'The sale stays on record as voided, its amount leaves your totals and any stock '
          'it took is put back. This cannot be undone.',
      confirmLabel: 'Void sale',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(salesRepositoryProvider).voidSale(sale.id);
      ref.invalidate(saleProvider(sale.id));
      ref.invalidate(salesProvider);
      ref.invalidate(productsProvider);
      ref.invalidate(dashboardSummaryProvider);
      if (context.mounted) showNobSnack(context, 'Sale voided.', tone: SnackTone.success);
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void back() => context.go(Routes.sales);
    return DetailLoader<Sale>(
      value: ref.watch(saleProvider(saleId)),
      title: 'Sale',
      onBack: back,
      onRetry: () => ref.invalidate(saleProvider(saleId)),
      builder: (sale) => _SaleView(sale: sale, onBack: back, onVoid: () => _void(context, ref, sale)),
    );
  }
}

class _SaleView extends ConsumerWidget {
  const _SaleView({required this.sale, required this.onBack, required this.onVoid});

  final Sale sale;
  final VoidCallback onBack;
  final VoidCallback onVoid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organization = ref.watch(activeOrganizationProvider);
    final workspaces = ref.watch(workspacesProvider).value ?? const [];
    final workspaceName = workspaces.where((w) => w.id == sale.workspaceId).map((w) => w.name).firstOrNull;
    final canVoid = ref.watch(canProvider(Permissions.salesVoid)) && !sale.isVoided;
    final soldAt = sale.soldAt;
    final note = sale.note;

    CommercialPdfData receipt() => CommercialPdfData(
          title: 'RECEIPT',
          number: sale.number,
          seller: organization == null
              ? const PdfParty(name: 'N.O Business')
              : sellerParty(organization, workspaceName: workspaceName),
          buyer: sale.customerName == null ? null : PdfParty(name: sale.customerName!),
          meta: [
            if (soldAt != null) ('Date', formatDateTime(soldAt)),
            ('Paid by', humanize(sale.paymentMethod)),
          ],
          items: sale.items,
          totals: sale.totals,
          currencyCode: sale.currencyCode,
          notes: note,
          footer: organization?.documentFooter,
          brandColorHex: organization?.brandColor,
          stamp: sale.isVoided ? 'VOID' : null,
        );

    return PageScaffold(
      title: sale.number,
      subtitle: [
        sale.customerName ?? 'Walk-in customer',
        if (soldAt != null) formatDateTime(soldAt),
      ].join(' · '),
      onBack: onBack,
      actions: [
        PdfActions(data: receipt),
        if (canVoid) DangerButton(label: 'Void sale', onPressed: onVoid, icon: Icons.block_rounded),
      ],
      child: TwoPane(
        primary: SectionCard(
          title: 'Items',
          child: RowGroup(
            children: [
              for (final item in sale.items) LineItemRow(item: item, currencyCode: sale.currencyCode),
            ],
          ),
        ),
        secondary: NobCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: sale.isVoided
                    ? const StatusBadge(label: 'Voided', tone: BadgeTone.danger)
                    : const StatusBadge(label: 'Completed', tone: BadgeTone.success),
              ),
              const SizedBox(height: NobSpace.lg),
              LabeledValue(label: 'Payment method', value: humanize(sale.paymentMethod)),
              if (workspaceName != null) ...[
                const SizedBox(height: NobSpace.md),
                LabeledValue(label: 'Workspace', value: workspaceName),
              ],
              if (note != null) ...[
                const SizedBox(height: NobSpace.md),
                LabeledValue(label: 'Note', value: note),
              ],
              const SizedBox(height: NobSpace.lg),
              TotalsSummary(totals: sale.totals, currencyCode: sale.currencyCode),
            ],
          ),
        ),
      ),
    );
  }
}
