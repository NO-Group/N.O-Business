import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_gate.dart';
import '../../../core/design_system/components/buttons.dart';
import '../../../core/design_system/components/fields.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/validators.dart';
import '../application/auth_providers.dart';
import '../data/auth_repository.dart';
import 'auth_scaffold.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final email = _email.text.trim();
      final outcome = await ref
          .read(authRepositoryProvider)
          .signUp(fullName: _name.text, email: email, password: _password.text);
      if (!mounted) return;
      if (outcome == SignUpOutcome.confirmationRequired) {
        context.go(Uri(path: Routes.confirmEmail, queryParameters: {'email': email}).toString());
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
      title: 'Create your account',
      subtitle: 'Set up your login first. You will create or join an organization next.',
      footer: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Already registered?', style: NobText.body.copyWith(color: NobColors.textSecondary)),
          TextButton(
            onPressed: _submitting ? null : () => context.go(Routes.signIn),
            child: const Text('Sign in'),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              textInputAction: TextInputAction.next,
              validator: (value) => Validators.length(value, min: 2, max: 120, label: 'Full name'),
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: NobSpace.lg),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              autocorrect: false,
              validator: Validators.email,
              decoration: const InputDecoration(
                labelText: 'Work email',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
            ),
            const SizedBox(height: NobSpace.lg),
            PasswordField(
              controller: _password,
              autofillHints: const [AutofillHints.newPassword],
              validator: Validators.password,
              helperText: 'At least 10 characters, with a letter and a number.',
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: NobSpace.xl),
            if (error != null) ...[
              FormMessage(error),
              const SizedBox(height: NobSpace.lg),
            ],
            PrimaryButton(label: 'Create account', onPressed: _submit, loading: _submitting, expanded: true),
          ],
        ),
      ),
    );
  }
}
