import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_gate.dart';
import '../../../core/design_system/components/buttons.dart';
import '../../../core/design_system/components/fields.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../application/auth_providers.dart';
import 'auth_scaffold.dart';

/// Second step of sign-up: enter the code that was emailed.
class ConfirmEmailScreen extends ConsumerStatefulWidget {
  const ConfirmEmailScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<ConfirmEmailScreen> createState() => _ConfirmEmailScreenState();
}

class _ConfirmEmailScreenState extends ConsumerState<ConfirmEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _submitting = false;
  bool _resending = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
      _notice = null;
    });
    try {
      await ref.read(authRepositoryProvider).confirmEmail(email: widget.email, code: _code.text);
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
      _notice = null;
    });
    try {
      await ref.read(authRepositoryProvider).resendConfirmation(widget.email);
      if (!mounted) return;
      setState(() => _notice = 'A new code is on its way.');
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final notice = _notice;
    return AuthScaffold(
      title: 'Confirm your email',
      subtitle: 'Enter the code we sent to ${widget.email}.',
      footer: TextButton(
        onPressed: _submitting ? null : () => context.go(Routes.signIn),
        child: const Text('Back to sign in'),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _code,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (value) =>
                  (value ?? '').trim().length < 6 ? 'Enter the code from the email' : null,
              style: NobText.title.copyWith(letterSpacing: 6),
              decoration: const InputDecoration(labelText: 'Confirmation code'),
            ),
            const SizedBox(height: NobSpace.lg),
            if (error != null) ...[FormMessage(error), const SizedBox(height: NobSpace.lg)],
            if (notice != null) ...[
              FormMessage(notice, isError: false),
              const SizedBox(height: NobSpace.lg),
            ],
            PrimaryButton(
              label: 'Confirm',
              onPressed: _submit,
              loading: _submitting,
              expanded: true,
            ),
            const SizedBox(height: NobSpace.sm),
            TextButton(
              onPressed: _resending || _submitting ? null : _resend,
              child: Text(_resending ? 'Sending…' : 'Send a new code'),
            ),
          ],
        ),
      ),
    );
  }
}
