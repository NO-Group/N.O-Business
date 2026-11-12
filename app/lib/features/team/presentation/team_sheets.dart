import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/components/buttons.dart';
import '../../../core/design_system/components/feedback.dart';
import '../../../core/design_system/components/fields.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/validators.dart';
import '../../tenancy/application/tenancy_providers.dart';
import '../application/team_providers.dart';
import '../domain/team_models.dart';

Future<void> showInviteSheet(BuildContext context) => showNobSheet<void>(context, child: const _InviteSheet());

Future<void> showChangeRoleSheet(BuildContext context, Member member) =>
    showNobSheet<void>(context, child: _ChangeRoleSheet(member: member));

Future<void> showRoleSheet(BuildContext context, {Role? role, bool readOnly = false}) =>
    showNobSheet<void>(context, child: _RoleSheet(role: role, readOnly: readOnly));

/// Dropdown of the organization's roles. Shows a spinner while they load.
class _RolePicker extends ConsumerWidget {
  const _RolePicker({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = ref.watch(rolesProvider);
    return roles.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => FormMessage(AppFailure.from(error).message),
      data: (items) => DropdownButtonFormField<String>(
        initialValue: items.any((role) => role.id == value) ? value : null,
        decoration: const InputDecoration(labelText: 'Role'),
        items: [for (final role in items) DropdownMenuItem(value: role.id, child: Text(role.name))],
        onChanged: onChanged,
        validator: (selected) => selected == null ? 'Choose a role' : null,
      ),
    );
  }
}

class _InviteSheet extends ConsumerStatefulWidget {
  const _InviteSheet();

  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  String? _roleId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    final organizationId = ref.read(activeOrganizationIdProvider);
    final roleId = _roleId;
    if (organizationId == null || roleId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(teamRepositoryProvider)
          .invite(organizationId: organizationId, email: _email.text, roleId: roleId);
      ref.invalidate(invitationsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      showNobSnack(context, 'Invitation created.', tone: SnackTone.success);
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
    return SheetScaffold(
      title: 'Invite a team member',
      subtitle: 'They see the invitation when they sign in to N.O Business with this email '
          'address. No email is sent yet, so let them know.',
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        PrimaryButton(label: 'Create invitation', onPressed: _send, loading: _saving),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Email address'),
              validator: Validators.email,
            ),
            const SizedBox(height: NobSpace.lg),
            _RolePicker(value: _roleId, onChanged: (value) => setState(() => _roleId = value)),
            if (error != null) ...[const SizedBox(height: NobSpace.lg), FormMessage(error)],
          ],
        ),
      ),
    );
  }
}

class _ChangeRoleSheet extends ConsumerStatefulWidget {
  const _ChangeRoleSheet({required this.member});

  final Member member;

  @override
  ConsumerState<_ChangeRoleSheet> createState() => _ChangeRoleSheetState();
}

class _ChangeRoleSheetState extends ConsumerState<_ChangeRoleSheet> {
  late String? _roleId = widget.member.roleId;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    final roleId = _roleId;
    if (_saving || roleId == null) return;
    if (roleId == widget.member.roleId) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(teamRepositoryProvider).setMemberRole(widget.member.membershipId, roleId);
      ref.invalidate(membersProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      showNobSnack(context, 'Role updated.', tone: SnackTone.success);
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
    return SheetScaffold(
      title: 'Change role',
      subtitle: widget.member.displayName,
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        PrimaryButton(label: 'Save', onPressed: _save, loading: _saving),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RolePicker(value: _roleId, onChanged: (value) => setState(() => _roleId = value)),
          const SizedBox(height: NobSpace.md),
          Text(
            'You can only assign roles whose permissions you hold yourself.',
            style: NobText.bodySmall.copyWith(color: NobColors.textSecondary),
          ),
          if (error != null) ...[const SizedBox(height: NobSpace.lg), FormMessage(error)],
        ],
      ),
    );
  }
}

class _RoleSheet extends ConsumerStatefulWidget {
  const _RoleSheet({this.role, required this.readOnly});

  final Role? role;
  final bool readOnly;

  @override
  ConsumerState<_RoleSheet> createState() => _RoleSheetState();
}

class _RoleSheetState extends ConsumerState<_RoleSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.role?.name);
  late final _description = TextEditingController(text: widget.role?.description);
  late final Set<String> _selected = {...?widget.role?.permissions};
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    final organizationId = ref.read(activeOrganizationIdProvider);
    if (organizationId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(teamRepositoryProvider).saveRole(
            organizationId: organizationId,
            roleId: widget.role?.id,
            name: _name.text,
            description: _description.text,
            permissions: _selected,
          );
      ref.invalidate(rolesProvider);
      // Members holding this role get the new permissions; refresh our own
      // context in case it is ours.
      ref.invalidate(myContextProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      showNobSnack(context, 'Role saved.', tone: SnackTone.success);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = AppFailure.from(error).message;
      });
    }
  }

  Future<void> _delete() async {
    final role = widget.role;
    if (role == null || _saving) return;
    final confirmed = await confirmAction(
      context,
      title: 'Delete the ${role.name} role?',
      message: 'A role that is still assigned to members or invitations cannot be deleted.',
      confirmLabel: 'Delete role',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(teamRepositoryProvider).deleteRole(role.id);
      ref.invalidate(rolesProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      showNobSnack(context, 'Role deleted.', tone: SnackTone.success);
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
    final role = widget.role;
    final readOnly = widget.readOnly;
    final catalogue = ref.watch(permissionCatalogueProvider);
    final mine = ref.watch(permissionsProvider);
    final error = _error;

    return SheetScaffold(
      title: role == null ? 'New role' : role.name,
      subtitle: role == null
          ? 'A custom set of permissions for this organization.'
          : role.isOwner
              ? 'Owners always hold every permission.'
              : role.isSystem
                  ? 'Built-in role. Create a custom role to use a different set of permissions.'
                  : null,
      actions: [
        if (role != null && !readOnly)
          DangerButton(label: 'Delete', onPressed: _saving ? null : _delete),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(readOnly ? 'Close' : 'Cancel'),
        ),
        if (!readOnly) PrimaryButton(label: 'Save role', onPressed: _save, loading: _saving),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!readOnly) ...[
              TextFormField(
                controller: _name,
                autofocus: role == null,
                decoration: const InputDecoration(labelText: 'Role name'),
                validator: (value) => Validators.length(value, min: 2, max: 60, label: 'Name'),
              ),
              const SizedBox(height: NobSpace.lg),
              TextFormField(
                controller: _description,
                maxLength: 300,
                decoration: const InputDecoration(labelText: 'Description (optional)', counterText: ''),
              ),
              const SizedBox(height: NobSpace.lg),
            ],
            catalogue.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => FormMessage(AppFailure.from(error).message),
              data: (items) {
                final modules = <String, List<PermissionInfo>>{};
                for (final item in items) {
                  modules.putIfAbsent(item.module, () => []).add(item);
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final entry in modules.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: NobSpace.md, bottom: NobSpace.xs),
                        child: Text(
                          entry.key.toUpperCase(),
                          style: NobText.overline.copyWith(color: NobColors.textMuted),
                        ),
                      ),
                      for (final permission in entry.value)
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: (role?.isOwner ?? false) || _selected.contains(permission.key),
                          // A permission you do not hold cannot be granted;
                          // the database rejects it as well.
                          onChanged: readOnly || !mine.contains(permission.key)
                              ? null
                              : (checked) => setState(() {
                                    if (checked ?? false) {
                                      _selected.add(permission.key);
                                    } else {
                                      _selected.remove(permission.key);
                                    }
                                  }),
                          title: Text(permission.description),
                        ),
                    ],
                  ],
                );
              },
            ),
            if (error != null) ...[const SizedBox(height: NobSpace.lg), FormMessage(error)],
          ],
        ),
      ),
    );
  }
}
