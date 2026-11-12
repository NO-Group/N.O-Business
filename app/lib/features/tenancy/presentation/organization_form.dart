import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/components/buttons.dart';
import '../../../core/design_system/components/fields.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/reference/reference_data.dart';
import '../../../core/utils/validators.dart';
import '../application/tenancy_providers.dart';
import '../domain/models.dart';

/// Form that creates an organization and its first workspace.
///
/// Used by onboarding and by "New organization" in settings. On success the
/// new organization becomes the active one and [onCreated] is called.
class OrganizationForm extends ConsumerStatefulWidget {
  const OrganizationForm({super.key, this.onCreated, this.submitLabel = 'Create organization'});

  final VoidCallback? onCreated;
  final String submitLabel;

  @override
  ConsumerState<OrganizationForm> createState() => _OrganizationFormState();
}

class _OrganizationFormState extends ConsumerState<OrganizationForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _country = TextEditingController();
  final _workspace = TextEditingController(text: 'Main');
  String _currency = 'USD';
  String _timeZone = 'UTC';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _country.dispose();
    _workspace.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final organizationId = await ref.read(tenancyRepositoryProvider).createOrganization(
            NewOrganization(
              name: _name.text.trim(),
              currencyCode: _currency,
              countryCode: nullIfBlank(_country.text)?.toUpperCase(),
              timezone: _timeZone,
              workspaceName: _workspace.text.trim(),
            ),
          );
      ref.read(selectedOrganizationProvider.notifier).select(organizationId);
      ref.invalidate(myContextProvider);
      await ref.read(myContextProvider.future);
      if (!mounted) return;
      widget.onCreated?.call();
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            validator: (value) => Validators.length(value, min: 2, max: 120, label: 'Organization name'),
            decoration: const InputDecoration(
              labelText: 'Organization name',
              prefixIcon: Icon(Icons.apartment_rounded),
            ),
          ),
          const SizedBox(height: NobSpace.lg),
          DropdownButtonFormField<String>(
            initialValue: _currency,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Currency',
              helperText: 'Used for prices, sales and invoices.',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
            items: [
              for (final currency in currencies)
                DropdownMenuItem(value: currency.code, child: Text('${currency.code} · ${currency.name}')),
            ],
            onChanged: _submitting ? null : (value) => setState(() => _currency = value ?? _currency),
          ),
          const SizedBox(height: NobSpace.lg),
          DropdownButtonFormField<String>(
            initialValue: _timeZone,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Time zone',
              helperText: 'Decides which day a sale or payment falls on in reports.',
              prefixIcon: Icon(Icons.schedule_rounded),
            ),
            items: [
              for (final zone in timeZones) DropdownMenuItem(value: zone, child: Text(zone.replaceAll('_', ' '))),
            ],
            onChanged: _submitting ? null : (value) => setState(() => _timeZone = value ?? _timeZone),
          ),
          const SizedBox(height: NobSpace.lg),
          TextFormField(
            controller: _country,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
              LengthLimitingTextInputFormatter(2),
            ],
            validator: (value) {
              final text = (value ?? '').trim();
              return text.isEmpty || text.length == 2 ? null : 'Use the two-letter country code';
            },
            decoration: const InputDecoration(
              labelText: 'Country code (optional)',
              hintText: 'e.g. NG, GB, US',
              prefixIcon: Icon(Icons.public_rounded),
            ),
          ),
          const SizedBox(height: NobSpace.lg),
          TextFormField(
            controller: _workspace,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            validator: (value) => Validators.length(value, min: 2, max: 80, label: 'Workspace name'),
            decoration: const InputDecoration(
              labelText: 'First workspace',
              helperText: 'A branch or location. Stock and sales are tracked per workspace.',
              prefixIcon: Icon(Icons.storefront_outlined),
            ),
          ),
          const SizedBox(height: NobSpace.xl),
          if (error != null) ...[
            FormMessage(error),
            const SizedBox(height: NobSpace.lg),
          ],
          PrimaryButton(label: widget.submitLabel, onPressed: _submit, loading: _submitting, expanded: true),
        ],
      ),
    );
  }
}
