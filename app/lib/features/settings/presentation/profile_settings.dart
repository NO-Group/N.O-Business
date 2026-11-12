import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/components/buttons.dart';
import '../../../core/design_system/components/feedback.dart';
import '../../../core/design_system/components/fields.dart';
import '../../../core/design_system/components/nob_card.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/utils/validators.dart';
import '../../auth/application/auth_providers.dart';
import '../../tenancy/application/tenancy_providers.dart';
import '../../tenancy/presentation/onboarding_screen.dart';

/// The signed-in person's own details, password and invitations.
class ProfileSettings extends ConsumerWidget {
  const ProfileSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myContext = ref.watch(myContextProvider).value;
    final invitations = myContext?.invitations ?? const [];
    final config = ref.watch(appConfigProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (invitations.isNotEmpty) ...[
          SectionCard(
            title: 'Invitations',
            subtitle: 'Organizations that have invited you to join.',
            child: Column(
              children: [
                for (final invitation in invitations) InvitationTile(invitation: invitation),
              ],
            ),
          ),
          const SizedBox(height: NobSpace.lg),
        ],
        const SectionCard(title: 'Profile', child: _ProfileForm()),
        const SizedBox(height: NobSpace.lg),
        const SectionCard(
          title: 'Password',
          subtitle: 'Use at least 10 characters. You stay signed in on this device.',
          child: _PasswordForm(),
        ),
        const SizedBox(height: NobSpace.lg),
        SectionCard(
          title: 'Session',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Signing out removes your session from this device.',
                style: NobText.body.copyWith(color: NobColors.textSecondary),
              ),
              const SizedBox(height: NobSpace.lg),
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await ref.read(authRepositoryProvider).signOut();
                  } catch (error) {
                    if (context.mounted) showFailure(context, error);
                  }
                },
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
        const SizedBox(height: NobSpace.lg),
        Text(
          'N.O Business ${config.appVersion} · N.O Group',
          style: NobText.label.copyWith(color: NobColors.textMuted),
        ),
      ],
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm();

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: ref.read(myContextProvider).value?.profile.fullName,
  );
  late final _phone = TextEditingController(text: ref.read(myContextProvider).value?.profile.phone);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final phone = nullIfBlank(_phone.text);
    try {
      await ref
          .read(tenancyRepositoryProvider)
          .updateProfile(
            userId: userId,
            fullName: _name.text.trim(),
            phone: phone == null ? null : Validators.normalizePhone(phone),
          );
      ref.invalidate(myContextProvider);
      if (!mounted) return;
      setState(() => _saving = false);
      showNobSnack(context, 'Profile saved.', tone: SnackTone.success);
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
    final email = ref.watch(myContextProvider).value?.profile.email ?? '';
    final error = _error;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledValue(label: 'Email', value: email),
          const SizedBox(height: NobSpace.lg),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(labelText: 'Full name'),
            validator: (value) => Validators.length(value, min: 1, max: 120, label: 'Name'),
          ),
          const SizedBox(height: NobSpace.lg),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone (optional)',
              helperText: 'International format, for example +234 801 234 5678',
            ),
            validator: Validators.phone,
          ),
          if (error != null) ...[const SizedBox(height: NobSpace.lg), FormMessage(error)],
          const SizedBox(height: NobSpace.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: PrimaryButton(label: 'Save profile', onPressed: _save, loading: _saving),
          ),
        ],
      ),
    );
  }
}

class _PasswordForm extends ConsumerStatefulWidget {
  const _PasswordForm();

  @override
  ConsumerState<_PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends ConsumerState<_PasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).changePassword(_password.text);
      if (!mounted) return;
      _password.clear();
      _confirm.clear();
      setState(() => _saving = false);
      showNobSnack(context, 'Password changed.', tone: SnackTone.success);
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
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PasswordField(
            controller: _password,
            label: 'New password',
            validator: Validators.password,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
          ),
          const SizedBox(height: NobSpace.lg),
          PasswordField(
            controller: _confirm,
            label: 'Confirm new password',
            validator: (value) => value == _password.text ? null : 'The passwords do not match',
            autofillHints: const [AutofillHints.newPassword],
            onSubmitted: (_) => _save(),
          ),
          if (error != null) ...[const SizedBox(height: NobSpace.lg), FormMessage(error)],
          const SizedBox(height: NobSpace.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: PrimaryButton(label: 'Change password', onPressed: _save, loading: _saving),
          ),
        ],
      ),
    );
  }
}
