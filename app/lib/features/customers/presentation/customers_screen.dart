import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_gate.dart';
import '../../../core/design_system/components/fields.dart';
import '../../../core/design_system/components/list_panel.dart';
import '../../../core/design_system/components/page_scaffold.dart';
import '../../../core/design_system/components/state_views.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/supabase/query_utils.dart';
import '../../tenancy/application/tenancy_providers.dart';
import '../../tenancy/domain/permissions.dart';
import '../application/customer_providers.dart';
import 'customer_form.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _query = '';

  Future<void> _add() async {
    final id = await showCustomerForm(context);
    if (id != null && mounted) context.go('${Routes.customers}/$id');
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(canProvider(Permissions.customersRead))) {
      return const PageScaffold(title: 'Customers', scrollable: false, child: NoAccessState());
    }
    final canWrite = ref.watch(canProvider(Permissions.customersWrite));
    final customers = ref.watch(customersProvider(_query));

    return PageScaffold(
      title: 'Customers',
      subtitle: 'People and companies you sell to.',
      scrollable: false,
      actions: [
        if (canWrite)
          FilledButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New customer'),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SearchField(
            hint: 'Search by name, email or phone',
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: NobSpace.lg),
          Expanded(
            child: AsyncView(
              value: customers,
              onRetry: () => ref.invalidate(customersProvider),
              builder: (items) {
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.groups_2_outlined,
                    title: _query.isEmpty ? 'No customers yet' : 'No matches',
                    message: _query.isEmpty
                        ? 'Add the people and companies you sell to. They appear on quotations and invoices.'
                        : 'No customer matches "$_query".',
                    action: _query.isEmpty && canWrite
                        ? FilledButton(onPressed: _add, child: const Text('Add a customer'))
                        : null,
                  );
                }
                return ListPanel(
                  itemCount: items.length,
                  footer: items.length >= listPageSize
                      ? const Text('Showing the first $listPageSize customers. Search to narrow the list.')
                      : null,
                  itemBuilder: (context, index) {
                    final customer = items[index];
                    return ListRow(
                      leading: RowIcon(
                        customer.isCompany ? Icons.apartment_outlined : Icons.person_outline_rounded,
                      ),
                      title: customer.name,
                      subtitle: customer.contactLine,
                      trailing: const Icon(Icons.chevron_right_rounded, color: NobColors.textMuted),
                      onTap: () => context.go('${Routes.customers}/${customer.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
