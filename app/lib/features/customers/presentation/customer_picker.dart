import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/components/feedback.dart';
import '../../../core/design_system/components/fields.dart';
import '../../../core/design_system/components/list_panel.dart';
import '../../../core/design_system/components/state_views.dart';
import '../../../core/design_system/tokens.dart';
import '../../tenancy/application/tenancy_providers.dart';
import '../../tenancy/domain/permissions.dart';
import '../application/customer_providers.dart';
import '../domain/customer.dart';
import 'customer_form.dart';

/// Lets the user pick a customer of the active organization, or add one.
Future<Customer?> showCustomerPicker(BuildContext context) =>
    showNobSheet<Customer>(context, child: const _CustomerPicker());

class _CustomerPicker extends ConsumerStatefulWidget {
  const _CustomerPicker();

  @override
  ConsumerState<_CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends ConsumerState<_CustomerPicker> {
  String _query = '';

  Future<void> _create() async {
    final id = await showCustomerForm(context);
    if (id == null || !mounted) return;
    final customer = await ref.read(customerProvider(id).future);
    if (customer != null && mounted) Navigator.of(context).pop(customer);
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider(_query));
    final canWrite = ref.watch(canProvider(Permissions.customersWrite));
    return SizedBox(
      height: 520,
      child: Padding(
        padding: const EdgeInsets.all(NobSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Choose a customer', style: NobText.title)),
                if (canWrite)
                  TextButton.icon(
                    onPressed: _create,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New'),
                  ),
              ],
            ),
            const SizedBox(height: NobSpace.md),
            SearchField(hint: 'Search customers', onChanged: (value) => setState(() => _query = value)),
            const SizedBox(height: NobSpace.md),
            Expanded(
              child: AsyncView(
                value: customers,
                onRetry: () => ref.invalidate(customersProvider),
                builder: (items) => items.isEmpty
                    ? EmptyState(
                        icon: Icons.groups_2_outlined,
                        title: _query.isEmpty ? 'No customers yet' : 'No matches',
                        message: _query.isEmpty
                            ? 'Add a customer to continue.'
                            : 'No customer matches "$_query".',
                      )
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (context, index) {
                          final customer = items[index];
                          return ListRow(
                            dense: true,
                            leading: RowIcon(
                              customer.isCompany ? Icons.apartment_outlined : Icons.person_outline_rounded,
                            ),
                            title: customer.name,
                            subtitle: customer.contactLine,
                            onTap: () => Navigator.of(context).pop(customer),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
