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
import 'auth_scaffold.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
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
      await ref.read(authRepositoryProvider).signIn(email: _email.text, password: _password.text);
      // The router reacts to the new session; nothing else to do here.
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
      title: 'Welcome back',
      subtitle: 'Sign in to your N.O Business account.',
      footer: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('New here?', style: NobText.body.copyWith(color: NobColors.textSecondary)),
          TextButton(
            onPressed: _submitting ? null : () => context.go(Routes.signUp),
            child: const Text('Create an account'),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username, AutofillHints.email],
              textInputAction: TextInputAction.next,
              autocorrect: false,
              validator: Validators.email,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
            ),
            const SizedBox(height: NobSpace.lg),
            PasswordField(
              controller: _password,
              validator: (value) => Validators.required(value, label: 'Password'),
              onSubmitted: (_) => _submit(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _submitting ? null : () => context.go(Routes.resetPassword),
                child: const Text('Forgot password?'),
              ),
            ),
            if (error != null) ...[
              FormMessage(error),
              const SizedBox(height: NobSpace.lg),
            ] else
              const SizedBox(height: NobSpace.sm),
            PrimaryButton(label: 'Sign in', onPressed: _submit, loading: _submitting, expanded: true),
          ],
        ),
      ),
    );
  }
}
