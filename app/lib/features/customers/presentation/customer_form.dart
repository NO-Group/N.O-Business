import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/components/buttons.dart';
import '../../../core/design_system/components/feedback.dart';
import '../../../core/design_system/components/fields.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/validators.dart';
import '../../tenancy/application/tenancy_providers.dart';
import '../application/customer_providers.dart';
import '../domain/customer.dart';

/// Opens the create/edit form. Resolves to the saved customer's id, or null
/// when the form was dismissed.
Future<String?> showCustomerForm(BuildContext context, {Customer? customer}) =>
    showNobSheet<String>(context, child: CustomerForm(customer: customer));

class CustomerForm extends ConsumerStatefulWidget {
  const CustomerForm({super.key, this.customer});

  final Customer? customer;

  @override
  ConsumerState<CustomerForm> createState() => _CustomerFormState();
}

class _CustomerFormState extends ConsumerState<CustomerForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.customer?.name);
  late final _email = TextEditingController(text: widget.customer?.email);
  late final _phone = TextEditingController(text: widget.customer?.phone);
  late final _address = TextEditingController(text: widget.customer?.address);
  late final _taxId = TextEditingController(text: widget.customer?.taxId);
  late final _notes = TextEditingController(text: widget.customer?.notes);
  late String _kind = widget.customer?.kind ?? 'individual';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_name, _email, _phone, _address, _taxId, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    final organizationId = ref.read(activeOrganizationIdProvider);
    if (organizationId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final phone = nullIfBlank(_phone.text);
    final input = CustomerInput(
      kind: _kind,
      name: _name.text,
      email: nullIfBlank(_email.text)?.toLowerCase(),
      phone: phone == null ? null : Validators.normalizePhone(phone),
      address: nullIfBlank(_address.text),
      taxId: nullIfBlank(_taxId.text),
      notes: nullIfBlank(_notes.text),
    );
    try {
      final repository = ref.read(customerRepositoryProvider);
      final existing = widget.customer;
      final String id;
      if (existing == null) {
        id = (await repository.create(organizationId, input)).id;
      } else {
        await repository.update(existing.id, input);
        id = existing.id;
      }
      ref.invalidate(customersProvider);
      ref.invalidate(customerProvider(id));
      if (!mounted) return;
      Navigator.of(context).pop(id);
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
    final error = _error;
    return SheetScaffold(
      title: widget.customer == null ? 'New customer' : 'Edit customer',
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        PrimaryButton(label: 'Save customer', onPressed: _save, loading: _saving),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'individual', label: Text('Individual'), icon: Icon(Icons.person_outline)),
                ButtonSegment(value: 'company', label: Text('Company'), icon: Icon(Icons.apartment_outlined)),
              ],
              selected: {_kind},
              onSelectionChanged: (selection) => setState(() => _kind = selection.first),
            ),
            const SizedBox(height: NobSpace.lg),
            TextFormField(
              controller: _name,
              autofocus: widget.customer == null,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: _kind == 'company' ? 'Company name' : 'Full name'),
              validator: (value) => Validators.length(value, min: 1, max: 160, label: 'Name'),
            ),
            const SizedBox(height: NobSpace.lg),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Email (optional)'),
              validator: (value) => Validators.email(value, optional: true),
            ),
            const SizedBox(height: NobSpace.lg),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                helperText: 'International format, for example +234 801 234 5678',
              ),
              validator: Validators.phone,
            ),
            const SizedBox(height: NobSpace.lg),
            TextFormField(
              controller: _address,
              minLines: 1,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Address (optional)', counterText: ''),
            ),
            const SizedBox(height: NobSpace.lg),
            TextFormField(
              controller: _taxId,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'Tax ID (optional)', counterText: ''),
            ),
            const SizedBox(height: NobSpace.lg),
            TextFormField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              maxLength: 2000,
              decoration: const InputDecoration(labelText: 'Notes (optional)', counterText: ''),
            ),
            if (error != null) ...[const SizedBox(height: NobSpace.lg), FormMessage(error)],
          ],
        ),
      ),
    );
  }
}
