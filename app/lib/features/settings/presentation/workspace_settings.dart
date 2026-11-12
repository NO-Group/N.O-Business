import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/components/buttons.dart';
import '../../../core/design_system/components/feedback.dart';
import '../../../core/design_system/components/fields.dart';
import '../../../core/design_system/components/list_panel.dart';
import '../../../core/design_system/components/nob_card.dart';
import '../../../core/design_system/components/status_badge.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/validators.dart';
import '../../tenancy/application/tenancy_providers.dart';
import '../../tenancy/domain/models.dart';

/// Branches or locations of the active organization. Stock, sales and
/// billing documents belong to a workspace.
class WorkspaceSettings extends ConsumerWidget {
  const WorkspaceSettings({super.key, required this.editable});

  /// False when the active role lacks `workspaces.manage`.
  final bool editable;

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
    String done,
  ) async {
    try {
      await action();
      ref.invalidate(workspacesProvider);
      if (context.mounted) showNobSnack(context, done, tone: SnackTone.success);
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaces = ref.watch(workspacesProvider);
    final repository = ref.watch(tenancyRepositoryProvider);

    return SectionCard(
      title: 'Workspaces',
      subtitle:
          'Branches or locations. Each keeps its own stock, sales, quotations and invoices; '
          'customers and the catalogue are shared.',
      flush: true,
      trailing: editable
          ? FilledButton.icon(
              onPressed: () => showNobSheet<void>(context, child: const _WorkspaceSheet()),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add'),
            )
          : null,
      child: workspaces.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(NobSpace.xl),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(NobSpace.xl),
          child: FormMessage(AppFailure.from(error).message),
        ),
        data: (items) => RowGroup(
          children: [
            for (final workspace in items)
              ListRow(
                leading: RowIcon(
                  Icons.storefront_outlined,
                  color: workspace.isArchived ? NobColors.textMuted : NobColors.cyan,
                ),
                title: workspace.name,
                subtitle: workspace.address,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (workspace.isDefault)
                      const StatusBadge(label: 'Default', tone: BadgeTone.info),
                    if (workspace.isArchived)
                      const StatusBadge(label: 'Archived', tone: BadgeTone.warning),
                    if (editable)
                      MenuAnchor(
                        menuChildren: [
                          MenuItemButton(
                            leadingIcon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => showNobSheet<void>(
                              context,
                              child: _WorkspaceSheet(workspace: workspace),
                            ),
                            child: const Text('Rename'),
                          ),
                          if (!workspace.isDefault && !workspace.isArchived)
                            MenuItemButton(
                              leadingIcon: const Icon(Icons.star_outline_rounded, size: 18),
                              onPressed: () => _act(
                                context,
                                ref,
                                () => repository.setDefaultWorkspace(workspace.id),
                                '${workspace.name} is now the default workspace.',
                              ),
                              child: const Text('Make default'),
                            ),
                          // The default workspace cannot be archived; pick
                          // another default first.
                          if (!workspace.isDefault)
                            MenuItemButton(
                              leadingIcon: Icon(
                                workspace.isArchived
                                    ? Icons.unarchive_outlined
                                    : Icons.archive_outlined,
                                size: 18,
                              ),
                              onPressed: () => _act(
                                context,
                                ref,
                                () => repository.setWorkspaceArchived(
                                  workspace.id,
                                  archived: !workspace.isArchived,
                                ),
                                workspace.isArchived
                                    ? 'Workspace restored.'
                                    : 'Workspace archived.',
                              ),
                              child: Text(workspace.isArchived ? 'Restore' : 'Archive'),
                            ),
                        ],
                        builder: (context, controller, _) => IconButton(
                          tooltip: 'Actions for ${workspace.name}',
                          icon: const Icon(Icons.more_vert_rounded),
                          onPressed: () =>
                              controller.isOpen ? controller.close() : controller.open(),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceSheet extends ConsumerStatefulWidget {
  const _WorkspaceSheet({this.workspace});

  final Workspace? workspace;

  @override
  ConsumerState<_WorkspaceSheet> createState() => _WorkspaceSheetState();
}

class _WorkspaceSheetState extends ConsumerState<_WorkspaceSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.workspace?.name);
  late final _address = TextEditingController(text: widget.workspace?.address);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
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
      final repository = ref.read(tenancyRepositoryProvider);
      final existing = widget.workspace;
      if (existing == null) {
        await repository.createWorkspace(
          organizationId: organizationId,
          name: _name.text.trim(),
          address: nullIfBlank(_address.text),
        );
      } else {
        await repository.editWorkspace(
          existing.id,
          name: _name.text.trim(),
          address: nullIfBlank(_address.text),
        );
      }
      ref.invalidate(workspacesProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      showNobSnack(context, 'Workspace saved.', tone: SnackTone.success);
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
      title: widget.workspace == null ? 'New workspace' : 'Edit workspace',
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        PrimaryButton(label: 'Save workspace', onPressed: _save, loading: _saving),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                helperText: 'For example "Main branch" or "Warehouse".',
              ),
              validator: (value) => Validators.length(value, min: 2, max: 80, label: 'Name'),
            ),
            const SizedBox(height: NobSpace.lg),
            TextFormField(
              controller: _address,
              minLines: 1,
              maxLines: 3,
              maxLength: 300,
              decoration: const InputDecoration(labelText: 'Address (optional)', counterText: ''),
            ),
            if (error != null) ...[const SizedBox(height: NobSpace.lg), FormMessage(error)],
          ],
        ),
      ),
    );
  }
}
