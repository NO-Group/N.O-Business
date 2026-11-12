import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/components/feedback.dart';
import '../../core/design_system/tokens.dart';
import '../../core/utils/formatters.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/tenancy/application/tenancy_providers.dart';
import '../../features/tenancy/presentation/organization_form.dart';
import '../app_gate.dart';

/// Shows the active organization and lets the user switch or add one.
class OrganizationSwitcher extends ConsumerWidget {
  const OrganizationSwitcher({super.key, this.dense = false});

  /// Icon-only presentation for the collapsed rail.
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberships = ref.watch(myContextProvider).value?.memberships ?? const [];
    final active = ref.watch(activeMembershipProvider);
    if (active == null) return const SizedBox.shrink();

    final avatar = _InitialsBox(text: initialsOf(active.organization.name));

    return MenuAnchor(
      alignmentOffset: const Offset(0, NobSpace.xs),
      menuChildren: [
        for (final membership in memberships)
          MenuItemButton(
            onPressed: () {
              // Leave any record of the previous organization behind.
              ref.read(selectedOrganizationProvider.notifier).select(membership.organization.id);
              context.go(Routes.dashboard);
            },
            leadingIcon: Icon(
              membership.organization.id == active.organization.id
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 18,
              color: membership.organization.id == active.organization.id
                  ? NobColors.cyan
                  : NobColors.textMuted,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(membership.organization.name, style: NobText.subtitle),
                Text(
                  membership.role.name,
                  style: NobText.label.copyWith(color: NobColors.textSecondary),
                ),
              ],
            ),
          ),
        const Divider(),
        MenuItemButton(
          onPressed: () => _createOrganization(context),
          leadingIcon: const Icon(Icons.add_rounded, size: 18),
          child: const Text('New organization'),
        ),
      ],
      builder: (context, controller, _) {
        void toggle() => controller.isOpen ? controller.close() : controller.open();
        if (dense) {
          return Tooltip(
            message: active.organization.name,
            child: InkWell(borderRadius: NobRadius.medium, onTap: toggle, child: avatar),
          );
        }
        return Material(
          color: NobColors.backgroundRaised,
          shape: const RoundedRectangleBorder(
            borderRadius: NobRadius.medium,
            side: BorderSide(color: NobColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: toggle,
            child: Padding(
              padding: const EdgeInsets.all(NobSpace.sm),
              child: Row(
                children: [
                  avatar,
                  const SizedBox(width: NobSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          active.organization.name,
                          style: NobText.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          active.role.name,
                          style: NobText.label.copyWith(color: NobColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.unfold_more_rounded, size: 18),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _createOrganization(BuildContext context) {
    return showNobSheet<void>(
      context,
      child: Builder(
        builder: (sheetContext) => SingleChildScrollView(
          padding: const EdgeInsets.all(NobSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('New organization', style: NobText.title),
              const SizedBox(height: NobSpace.xs),
              Text(
                'A separate tenant with its own team, data and settings.',
                style: NobText.bodySmall.copyWith(color: NobColors.textSecondary),
              ),
              const SizedBox(height: NobSpace.xl),
              OrganizationForm(
                onCreated: () {
                  final router = GoRouter.of(sheetContext);
                  Navigator.of(sheetContext).pop();
                  router.go(Routes.dashboard);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows the active workspace and lets the user switch between the
/// organization's active workspaces.
class WorkspaceSwitcher extends ConsumerWidget {
  const WorkspaceSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaces = (ref.watch(workspacesProvider).value ?? const [])
        .where((workspace) => !workspace.isArchived)
        .toList();
    final active = ref.watch(activeWorkspaceProvider);
    if (active == null) return const SizedBox.shrink();

    return MenuAnchor(
      alignmentOffset: const Offset(0, NobSpace.xs),
      menuChildren: [
        for (final workspace in workspaces)
          MenuItemButton(
            onPressed: () => ref.read(selectedWorkspaceProvider.notifier).select(workspace.id),
            leadingIcon: Icon(
              workspace.id == active.id ? Icons.check_rounded : Icons.storefront_outlined,
              size: 18,
              color: workspace.id == active.id ? NobColors.cyan : NobColors.textMuted,
            ),
            child: Text(workspace.name),
          ),
      ],
      builder: (context, controller, _) => Tooltip(
        message: 'Workspace',
        child: OutlinedButton.icon(
          onPressed: workspaces.length < 2
              ? null
              : () => controller.isOpen ? controller.close() : controller.open(),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: NobSpace.md, vertical: NobSpace.sm),
            minimumSize: const Size(0, 40),
            disabledForegroundColor: NobColors.textPrimary,
          ),
          icon: const Icon(Icons.storefront_outlined, size: 18),
          label: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(active.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ),
    );
  }
}

/// Avatar with the user's initials; opens profile and sign-out actions.
class UserMenu extends ConsumerWidget {
  const UserMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myContextProvider).value?.profile;
    if (profile == null) return const SizedBox.shrink();

    return MenuAnchor(
      alignmentOffset: const Offset(0, NobSpace.sm),
      menuChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(NobSpace.lg, NobSpace.md, NobSpace.lg, NobSpace.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(profile.displayName, style: NobText.subtitle),
              Text(profile.email, style: NobText.label.copyWith(color: NobColors.textSecondary)),
            ],
          ),
        ),
        const Divider(),
        MenuItemButton(
          onPressed: () => context.go(Routes.settings),
          leadingIcon: const Icon(Icons.person_outline_rounded, size: 18),
          child: const Text('Profile and settings'),
        ),
        MenuItemButton(
          onPressed: () async {
            try {
              await ref.read(authRepositoryProvider).signOut();
            } catch (error) {
              if (context.mounted) showFailure(context, error);
            }
          },
          leadingIcon: const Icon(Icons.logout_rounded, size: 18),
          child: const Text('Sign out'),
        ),
      ],
      builder: (context, controller, _) => Tooltip(
        message: 'Account',
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => controller.isOpen ? controller.close() : controller.open(),
          child: CircleAvatar(
            radius: 17,
            backgroundColor: NobColors.cobalt.withValues(alpha: 0.3),
            child: Text(
              initialsOf(profile.displayName),
              style: NobText.label.copyWith(color: NobColors.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

class _InitialsBox extends StatelessWidget {
  const _InitialsBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: const BoxDecoration(gradient: NobGradients.action, borderRadius: NobRadius.small),
      child: Text(text, style: NobText.label.copyWith(color: NobColors.onAccent, fontSize: 13)),
    );
  }
}
