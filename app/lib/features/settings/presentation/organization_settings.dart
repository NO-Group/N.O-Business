import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_gate.dart';
import '../../../core/design_system/components/buttons.dart';
import '../../../core/design_system/components/feedback.dart';
import '../../../core/design_system/components/fields.dart';
import '../../../core/design_system/components/nob_card.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/reference/reference_data.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../tenancy/application/tenancy_providers.dart';
import '../../tenancy/domain/models.dart';

/// Profile of the active organization: what appears on documents, and the
/// defaults used for new records.
class OrganizationSettings extends ConsumerWidget {
  const OrganizationSettings({super.key, required this.editable});

  /// False when the active role lacks `org.manage`; the form is read-only.
  final bool editable;

  Future<void> _leave(BuildContext context, WidgetRef ref, Organization organization) async {
    final confirmed = await confirmAction(
      context,
      title: 'Leave ${organization.name}?',
      message: 'You lose access to this organization and its data. An owner or administrator '
          'would need to invite you again. The last owner cannot leave.',
      confirmLabel: 'Leave organization',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(tenancyRepositoryProvider).leaveOrganization(organization.id);
      ref.invalidate(myContextProvider);
      if (context.mounted) context.go(Routes.dashboard);
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(activeMembershipProvider);
    if (membership == null) return const SizedBox.shrink();
    final organization = membership.organization;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: organization.name,
          subtitle: editable
              ? 'These details appear on quotations, invoices and receipts.'
              : 'Only members with permission to manage the organization can change these details.',
          // A new form (and fresh controllers) per organization.
          child: _OrganizationForm(key: ValueKey(organization.id), organization: organization, editable: editable),
        ),
        const SizedBox(height: NobSpace.lg),
        SectionCard(
          title: 'Your membership',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LabeledValue(label: 'Role', value: membership.role.name),
              const SizedBox(height: NobSpace.lg),
              DangerButton(
                label: 'Leave organization',
                icon: Icons.exit_to_app_rounded,
                onPressed: () => _leave(context, ref, organization),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OrganizationForm extends ConsumerStatefulWidget {
  const _OrganizationForm({super.key, required this.organization, required this.editable});

  final Organization organization;
  final bool editable;

  @override
  ConsumerState<_OrganizationForm> createState() => _OrganizationFormState();
}

class _OrganizationFormState extends ConsumerState<_OrganizationForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.organization.name);
  late final _legalName = TextEditingController(text: widget.organization.legalName);
  late final _email = TextEditingController(text: widget.organization.email);
  late final _phone = TextEditingController(text: widget.organization.phone);
  late final _address = TextEditingController(text: widget.organization.address);
  late final _taxId = TextEditingController(text: widget.organization.taxId);
  late final _taxRate = TextEditingController(text: formatQuantity(widget.organization.defaultTaxRate));
  late final _brandColor = TextEditingController(text: widget.organization.brandColor);
  late final _footer = TextEditingController(text: widget.organization.documentFooter);
  late String _currency = widget.organization.currencyCode;
  late String _timezone = widget.organization.timezone;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _legalName,
      _email,
      _phone,
      _address,
      _taxId,
      _taxRate,
      _brandColor,
      _footer,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final phone = nullIfBlank(_phone.text);
    try {
      await ref.read(tenancyRepositoryProvider).updateOrganization(widget.organization.id, {
        'name': _name.text.trim(),
        'legal_name': nullIfBlank(_legalName.text),
        'email': nullIfBlank(_email.text)?.toLowerCase(),
        'phone': phone == null ? null : Validators.normalizePhone(phone),
        'address': nullIfBlank(_address.text),
        'tax_id': nullIfBlank(_taxId.text),
        'default_tax_rate': double.tryParse(_taxRate.text.trim()) ?? 0,
        'currency_code': _currency,
        'timezone': _timezone,
        'brand_color': nullIfBlank(_brandColor.text)?.toUpperCase(),
        'document_footer': nullIfBlank(_footer.text),
      });
      ref.invalidate(myContextProvider);
      if (!mounted) return;
      setState(() => _saving = false);
      showNobSnack(context, 'Organization saved.', tone: SnackTone.success);
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
    final editable = widget.editable;
    final error = _error;
    // Keep the stored value selectable even if it is not in the short list.
    final zones = timeZones.contains(_timezone) ? timeZones : [_timezone, ...timeZones];
    final knownCurrency = currencies.any((currency) => currency.code == _currency);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            enabled: editable,
            decoration: const InputDecoration(labelText: 'Organization name'),
            validator: (value) => Validators.length(value, min: 2, max: 120, label: 'Name'),
          ),
          const SizedBox(height: NobSpace.lg),
          TextFormField(
            controller: _legalName,
            enabled: editable,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Legal name (optional)',
              helperText: 'Printed on documents instead of the organization name.',
              counterText: '',
            ),
          ),
          const SizedBox(height: NobSpace.lg),
          TextFormField(
            controller: _email,
            enabled: editable,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Business email (optional)'),
            validator: (value) => Validators.email(value, optional: true),
          ),
          const SizedBox(height: NobSpace.lg),
          TextFormField(
            controller: _phone,
            enabled: editable,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Business phone (optional)',
              helperText: 'International format, for example +234 801 234 5678',
            ),
            validator: Validators.phone,
          ),
          const SizedBox(height: NobSpace.lg),
          TextFormField(
            controller: _address,
            enabled: editable,
            minLines: 1,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Address (optional)', counterText: ''),
          ),
          const SizedBox(height: NobSpace.lg),
          TextFormField(
            controller: _taxId,
            enabled: editable,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Tax ID (optional)', counterText: ''),
          ),
          const SizedBox(height: NobSpace.lg),
          DropdownButtonFormField<String>(
            initialValue: _currency,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Currency',
              helperText: 'Used for new records. Existing documents keep their currency.',
            ),
            items: [
              if (!knownCurrency) DropdownMenuItem(value: _currency, child: Text(_currency)),
              for (final currency in currencies)
                DropdownMenuItem(value: currency.code, child: Text('${currency.code} · ${currency.name}')),
            ],
            onChanged: editable ? (value) => setState(() => _currency = value ?? _currency) : null,
          ),
          const SizedBox(height: NobSpace.lg),
          DropdownButtonFormField<String>(
            initialValue: _timezone,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Time zone'),
            items: [for (final zone in zones) DropdownMenuItem(value: zone, child: Text(zone))],
            onChanged: editable ? (value) => setState(() => _timezone = value ?? _timezone) : null,
          ),
          const SizedBox(height: NobSpace.lg),
          TextFormField(
            controller: _taxRate,
            enabled: editable,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Default tax rate %',
              helperText: 'Applied to items that do not set their own rate.',
            ),
            validator: Validators.percentage,
          ),
          const SizedBox(height: NobSpace.lg),
          TextFormField(
            controller: _brandColor,
            enabled: editable,
            decoration: const InputDecoration(
              labelText: 'Document accent colour (optional)',
              helperText: 'Hex colour such as #075BFF, used on printed documents.',
            ),
            validator: (value) {
              final text = (value ?? '').trim();
              if (text.isEmpty || RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(text)) return null;
              return 'Use the form #RRGGBB';
            },
          ),
          const SizedBox(height: NobSpace.lg),
          TextFormField(
            controller: _footer,
            enabled: editable,
            minLines: 2,
            maxLines: 5,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Document footer (optional)',
              helperText: 'Bank details, payment terms or a thank-you line.',
              counterText: '',
            ),
          ),
          if (error != null) ...[const SizedBox(height: NobSpace.lg), FormMessage(error)],
          if (editable) ...[
            const SizedBox(height: NobSpace.lg),
            Align(
              alignment: Alignment.centerLeft,
              child: PrimaryButton(label: 'Save organization', onPressed: _save, loading: _saving),
            ),
          ],
        ],
      ),
    );
  }
}
