import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_gate.dart';
import '../../../core/design_system/components/buttons.dart';
import '../../../core/design_system/components/fields.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/validators.dart';
import '../application/auth_providers.dart';
import 'auth_scaffold.dart';

/// Password recovery in two steps on one screen: request a code by email,
/// then enter the code together with the new password.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _codeSent = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final repository = ref.read(authRepositoryProvider);
    try {
      if (!_codeSent) {
        await repository.requestPasswordReset(_email.text);
        if (!mounted) return;
        setState(() => _codeSent = true);
      } else {
        // Verifying the code signs the user in; the router then leaves this
        // screen on its own.
        await repository.completePasswordReset(
          email: _email.text,
          code: _code.text,
          newPassword: _password.text,
        );
      }
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
    return AuthScaffold(
      title: 'Reset your password',
      subtitle: _codeSent
          ? 'If an account exists for ${_email.text.trim()}, a code has been sent. Enter it with your new password.'
          : 'Enter your email and we will send you a reset code.',
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
              controller: _email,
              enabled: !_codeSent,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              textInputAction: _codeSent ? TextInputAction.next : TextInputAction.done,
              onFieldSubmitted: _codeSent ? null : (_) => _submit(),
              validator: Validators.email,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
            ),
            if (_codeSent) ...[
              const SizedBox(height: NobSpace.lg),
              TextFormField(
                controller: _code,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                textInputAction: TextInputAction.next,
                validator: (value) =>
                    (value ?? '').trim().length < 6 ? 'Enter the code from the email' : null,
                decoration: const InputDecoration(
                  labelText: 'Reset code',
                  prefixIcon: Icon(Icons.pin_outlined),
                ),
              ),
              const SizedBox(height: NobSpace.lg),
              PasswordField(
                controller: _password,
                label: 'New password',
                autofillHints: const [AutofillHints.newPassword],
                validator: Validators.password,
                helperText: 'At least 10 characters, with a letter and a number.',
                onSubmitted: (_) => _submit(),
              ),
            ],
            const SizedBox(height: NobSpace.xl),
            if (error != null) ...[FormMessage(error), const SizedBox(height: NobSpace.lg)],
            PrimaryButton(
              label: _codeSent ? 'Set new password' : 'Send reset code',
              onPressed: _submit,
              loading: _submitting,
              expanded: true,
            ),
            if (_codeSent)
              TextButton(
                onPressed: _submitting ? null : () => setState(() => _codeSent = false),
                child: const Text('Use a different email'),
              ),
          ],
        ),
      ),
    );
  }
}
