import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/components/feedback.dart';
import '../../../core/design_system/components/list_panel.dart';
import '../../../core/design_system/components/page_scaffold.dart';
import '../../../core/design_system/components/state_views.dart';
import '../../../core/design_system/components/status_badge.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/application/auth_providers.dart';
import '../../tenancy/application/tenancy_providers.dart';
import '../../tenancy/domain/permissions.dart';
import '../application/team_providers.dart';
import '../domain/team_models.dart';
import 'team_sheets.dart';

class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(canProvider(Permissions.membersRead))) {
      return const PageScaffold(title: 'Team', scrollable: false, child: NoAccessState());
    }
    final canManage = ref.watch(canProvider(Permissions.membersManage));
    final canRoles = ref.watch(canProvider(Permissions.rolesManage));
    final canAudit = ref.watch(canProvider(Permissions.auditRead));
    final organization = ref.watch(activeOrganizationProvider);

    final tabs = <(String, Widget)>[
      ('Members', _MembersTab(canManage: canManage)),
      ('Invitations', _InvitationsTab(canManage: canManage)),
      ('Roles', _RolesTab(canManage: canRoles)),
      if (canAudit) ('Activity', const _ActivityTab()),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: PageScaffold(
        title: 'Team',
        subtitle: organization == null
            ? 'Members, roles and access.'
            : 'Who can work in ${organization.name}, and what they may do.',
        scrollable: false,
        actions: [
          if (canRoles)
            OutlinedButton.icon(
              onPressed: () => showRoleSheet(context),
              icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
              label: const Text('New role'),
            ),
          if (canManage)
            FilledButton.icon(
              onPressed: () => showInviteSheet(context),
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
              label: const Text('Invite'),
            ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [for (final (label, _) in tabs) Tab(text: label)],
            ),
            const SizedBox(height: NobSpace.lg),
            Expanded(child: TabBarView(children: [for (final (_, view) in tabs) view])),
          ],
        ),
      ),
    );
  }
}

class _MembersTab extends ConsumerWidget {
  const _MembersTab({required this.canManage});

  final bool canManage;

  Future<void> _act(BuildContext context, WidgetRef ref, Future<void> Function() action, String done) async {
    try {
      await action();
      ref.invalidate(membersProvider);
      if (context.mounted) showNobSnack(context, done, tone: SnackTone.success);
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, Member member) async {
    final confirmed = await confirmAction(
      context,
      title: 'Remove ${member.displayName}?',
      message: 'They lose access to this organization immediately. Records they created stay.',
      confirmLabel: 'Remove member',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await _act(
      context,
      ref,
      () => ref.read(teamRepositoryProvider).removeMember(member.membershipId),
      'Member removed.',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider);
    final me = ref.watch(currentUserIdProvider);
    return AsyncView(
      value: members,
      onRetry: () => ref.invalidate(membersProvider),
      builder: (items) => ListPanel(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final member = items[index];
          final isMe = member.userId == me;
          return ListRow(
            leading: CircleAvatar(
              radius: 19,
              backgroundColor: NobColors.cobalt.withValues(alpha: 0.25),
              child: Text(
                initialsOf(member.displayName),
                style: NobText.label.copyWith(color: NobColors.textPrimary),
              ),
            ),
            title: isMe ? '${member.displayName} (you)' : member.displayName,
            subtitle: member.email,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (member.isSuspended)
                  const Padding(
                    padding: EdgeInsets.only(right: NobSpace.sm),
                    child: StatusBadge(label: 'Suspended', tone: BadgeTone.warning),
                  ),
                StatusBadge(label: member.roleName, tone: member.isOwner ? BadgeTone.accent : BadgeTone.info),
                // Nobody manages their own membership; the database enforces
                // the same rule.
                if (canManage && !isMe)
                  MenuAnchor(
                    menuChildren: [
                      MenuItemButton(
                        leadingIcon: const Icon(Icons.badge_outlined, size: 18),
                        onPressed: () => showChangeRoleSheet(context, member),
                        child: const Text('Change role'),
                      ),
                      MenuItemButton(
                        leadingIcon: Icon(
                          member.isSuspended ? Icons.play_circle_outline : Icons.pause_circle_outline,
                          size: 18,
                        ),
                        onPressed: () => _act(
                          context,
                          ref,
                          () => ref.read(teamRepositoryProvider).setMemberStatus(
                                member.membershipId,
                                member.isSuspended ? 'active' : 'suspended',
                              ),
                          member.isSuspended ? 'Access restored.' : 'Member suspended.',
                        ),
                        child: Text(member.isSuspended ? 'Restore access' : 'Suspend'),
                      ),
                      MenuItemButton(
                        leadingIcon: const Icon(Icons.person_remove_outlined, size: 18),
                        onPressed: () => _remove(context, ref, member),
                        child: const Text('Remove'),
                      ),
                    ],
                    builder: (context, controller, _) => IconButton(
                      tooltip: 'Actions for ${member.displayName}',
                      icon: const Icon(Icons.more_vert_rounded),
                      onPressed: () => controller.isOpen ? controller.close() : controller.open(),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InvitationsTab extends ConsumerWidget {
  const _InvitationsTab({required this.canManage});

  final bool canManage;

  Future<void> _revoke(BuildContext context, WidgetRef ref, Invitation invitation) async {
    try {
      await ref.read(teamRepositoryProvider).revokeInvitation(invitation.id);
      ref.invalidate(invitationsProvider);
      if (context.mounted) showNobSnack(context, 'Invitation revoked.', tone: SnackTone.success);
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitations = ref.watch(invitationsProvider);
    final now = DateTime.now();
    return AsyncView(
      value: invitations,
      onRetry: () => ref.invalidate(invitationsProvider),
      builder: (items) {
        if (items.isEmpty) {
          return EmptyState(
            icon: Icons.mark_email_unread_outlined,
            title: 'No pending invitations',
            message: 'Invite someone by email and choose their role. They see the invitation '
                'when they sign in to N.O Business with that address.',
            action: canManage
                ? FilledButton(onPressed: () => showInviteSheet(context), child: const Text('Invite someone'))
                : null,
          );
        }
        return ListPanel(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final invitation = items[index];
            final expires = invitation.expiresAt;
            final expired = invitation.isExpired(now);
            return ListRow(
              leading: const RowIcon(Icons.mail_outline_rounded),
              title: invitation.email,
              subtitle: [
                invitation.roleName,
                if (expires != null) expired ? 'Expired ${formatDate(expires)}' : 'Expires ${formatDate(expires)}',
              ].join(' · '),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (expired) const StatusBadge(label: 'Expired', tone: BadgeTone.warning),
                  if (canManage)
                    TextButton(
                      onPressed: () => _revoke(context, ref, invitation),
                      child: const Text('Revoke'),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _RolesTab extends ConsumerWidget {
  const _RolesTab({required this.canManage});

  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = ref.watch(rolesProvider);
    return AsyncView(
      value: roles,
      onRetry: () => ref.invalidate(rolesProvider),
      builder: (items) => ListPanel(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final role = items[index];
          return ListRow(
            leading: RowIcon(
              role.isOwner ? Icons.verified_user_outlined : Icons.admin_panel_settings_outlined,
              color: role.isSystem ? NobColors.violet : NobColors.cyan,
            ),
            title: role.name,
            subtitle: [
              if (role.description.isNotEmpty) role.description,
              role.isOwner ? 'Full access' : '${role.permissions.length} permissions',
            ].join(' · '),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusBadge(label: role.isSystem ? 'Built-in' : 'Custom'),
                const SizedBox(width: NobSpace.sm),
                const Icon(Icons.chevron_right_rounded, color: NobColors.textMuted),
              ],
            ),
            onTap: () => showRoleSheet(context, role: role, readOnly: role.isSystem || !canManage),
          );
        },
      ),
    );
  }
}

class _ActivityTab extends ConsumerWidget {
  const _ActivityTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trail = ref.watch(auditTrailProvider);
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final names = {for (final member in members) member.userId: member.displayName};
    return AsyncView(
      value: trail,
      onRetry: () => ref.invalidate(auditTrailProvider),
      builder: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.history_rounded,
            title: 'No activity yet',
            message: 'Changes to members, roles, stock and financial records are listed here.',
          );
        }
        return ListPanel(
          itemCount: items.length,
          footer: const Text('The 100 most recent entries. The audit trail cannot be edited or deleted.'),
          itemBuilder: (context, index) {
            final entry = items[index];
            final at = entry.createdAt;
            return ListRow(
              dense: true,
              leading: const RowIcon(Icons.history_rounded, color: NobColors.textSecondary),
              title: '${humanize(entry.action)} · ${humanize(entry.entityType)}',
              subtitle: [
                names[entry.actorId] ?? (entry.actorId == null ? 'System' : 'Former member'),
                if (at != null) formatDateTime(at),
              ].join(' · '),
            );
          },
        );
      },
    );
  }
}
