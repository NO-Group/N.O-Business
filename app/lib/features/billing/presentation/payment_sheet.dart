import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/components/buttons.dart';
import '../../../core/design_system/components/feedback.dart';
import '../../../core/design_system/components/fields.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/reference/reference_data.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/validators.dart';
import '../application/billing_providers.dart';
import '../domain/billing_models.dart';

/// Records a payment against an open invoice. Resolves to true when saved.
Future<bool> showPaymentSheet(BuildContext context, Invoice invoice) async =>
    await showNobSheet<bool>(context, child: _PaymentSheet(invoice: invoice)) ?? false;

class _PaymentSheet extends ConsumerStatefulWidget {
  const _PaymentSheet({required this.invoice});

  final Invoice invoice;

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: Money.toInput(widget.invoice.balanceMinor, widget.invoice.currencyCode),
  );
  final _reference = TextEditingController();
  String _method = paymentMethods.first;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  String? _validateAmount(String? value) {
    final minor = Money.parse(value ?? '', widget.invoice.currencyCode);
    if (minor == null || minor <= 0) return 'Enter the amount received';
    if (minor > widget.invoice.balanceMinor) {
      return 'No more than the balance of '
          '${Money.format(widget.invoice.balanceMinor, widget.invoice.currencyCode)}';
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(billingRepositoryProvider)
          .recordPayment(
            invoiceId: widget.invoice.id,
            amountMinor: Money.parse(_amount.text, widget.invoice.currencyCode) ?? 0,
            method: _method,
            reference: nullIfBlank(_reference.text),
          );
      if (mounted) Navigator.of(context).pop(true);
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
    final invoice = widget.invoice;
    final error = _error;
    return SheetScaffold(
      title: 'Record payment',
      subtitle:
          '${invoice.displayNumber} · '
          '${Money.format(invoice.balanceMinor, invoice.currencyCode)} outstanding',
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        PrimaryButton(label: 'Record payment', onPressed: _save, loading: _saving),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Amount received (${invoice.currencyCode})'),
              validator: _validateAmount,
            ),
            const SizedBox(height: NobSpace.lg),
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'Payment method'),
              items: [
                for (final method in paymentMethods)
                  DropdownMenuItem(value: method, child: Text(humanize(method))),
              ],
              onChanged: (value) => setState(() => _method = value ?? _method),
            ),
            const SizedBox(height: NobSpace.lg),
            TextFormField(
              controller: _reference,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Reference (optional)',
                helperText: 'Transfer reference, cheque number or receipt number.',
                counterText: '',
              ),
            ),
            if (error != null) ...[const SizedBox(height: NobSpace.lg), FormMessage(error)],
          ],
        ),
      ),
    );
  }
}
