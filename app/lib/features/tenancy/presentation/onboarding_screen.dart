import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/components/brand_mark.dart';
import '../../../core/design_system/components/feedback.dart';
import '../../../core/design_system/components/nob_card.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/application/auth_providers.dart';
import '../application/tenancy_providers.dart';
import '../domain/models.dart';
import 'organization_form.dart';

/// First-run screen for an account that belongs to no organization yet:
/// accept an invitation or create an organization.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myContext = ref.watch(myContextProvider).value;
    final invitations = myContext?.invitations ?? const <PendingInvitation>[];
    final name = myContext?.profile.displayName ?? '';

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: NobGradients.backdrop),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(NobSpace.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const BrandLockup(),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => ref.read(authRepositoryProvider).signOut(),
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: const Text('Sign out'),
                        ),
                      ],
                    ),
                    const SizedBox(height: NobSpace.xxl),
                    Text(name.isEmpty ? 'Welcome' : 'Welcome, $name', style: NobText.display),
                    const SizedBox(height: NobSpace.sm),
                    Text(
                      'An organization holds your team, customers, catalogue and records. '
                      'Join one you were invited to, or create your own.',
                      style: NobText.body.copyWith(color: NobColors.textSecondary),
                    ),
                    const SizedBox(height: NobSpace.xl),
                    if (invitations.isNotEmpty) ...[
                      SectionCard(
                        title: 'Invitations',
                        subtitle: 'Sent to ${myContext?.profile.email ?? 'your email'}',
                        child: Column(
                          children: [
                            for (final invitation in invitations) InvitationTile(invitation: invitation),
                          ],
                        ),
                      ),
                      const SizedBox(height: NobSpace.xl),
                    ],
                    const SectionCard(
                      title: 'Create an organization',
                      subtitle: 'You become its owner and can invite your team afterwards.',
                      child: OrganizationForm(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One pending invitation with an accept action.
class InvitationTile extends ConsumerStatefulWidget {
  const InvitationTile({super.key, required this.invitation});

  final PendingInvitation invitation;

  @override
  ConsumerState<InvitationTile> createState() => _InvitationTileState();
}

class _InvitationTileState extends ConsumerState<InvitationTile> {
  bool _accepting = false;

  Future<void> _accept() async {
    setState(() => _accepting = true);
    try {
      final organizationId =
          await ref.read(tenancyRepositoryProvider).acceptInvitation(widget.invitation.id);
      ref.read(selectedOrganizationProvider.notifier).select(organizationId);
      ref.invalidate(myContextProvider);
      if (mounted) showNobSnack(context, 'You joined ${widget.invitation.organizationName}.', tone: SnackTone.success);
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invitation = widget.invitation;
    final expires = invitation.expiresAt;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.mark_email_unread_outlined, color: NobColors.cyan),
      title: Text(invitation.organizationName),
      subtitle: Text(
        expires == null
            ? 'Role: ${invitation.roleName}'
            : 'Role: ${invitation.roleName} · expires ${formatDate(expires)}',
      ),
      trailing: FilledButton(
        onPressed: _accepting ? null : _accept,
        child: Text(_accepting ? 'Joining…' : 'Accept'),
      ),
    );
  }
}
