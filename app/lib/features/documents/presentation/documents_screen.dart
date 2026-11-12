import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/components/buttons.dart';
import '../../../core/design_system/components/feedback.dart';
import '../../../core/design_system/components/fields.dart';
import '../../../core/design_system/components/list_panel.dart';
import '../../../core/design_system/components/page_scaffold.dart';
import '../../../core/design_system/components/state_views.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/query_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../customers/domain/customer.dart';
import '../../customers/presentation/customer_picker.dart';
import '../../tenancy/application/tenancy_providers.dart';
import '../../tenancy/domain/permissions.dart';
import '../application/document_providers.dart';
import '../domain/document_file.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  String _query = '';
  String? _category;
  bool _picking = false;

  DocumentQuery get _filter => (query: _query, category: _category);

  Future<void> _upload() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picked = await FilePicker.pickFile(
        dialogTitle: 'Choose a document',
        type: FileType.custom,
        allowedExtensions: documentMimeTypes.keys.toList(),
      );
      if (picked == null || !mounted) return;
      if (mimeTypeForFileName(picked.name) == null) {
        showNobSnack(context, 'That file type is not supported.', tone: SnackTone.danger);
        return;
      }
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty || bytes.length > maxDocumentBytes) {
        showNobSnack(context, 'Files can be up to 20 MB.', tone: SnackTone.danger);
        return;
      }
      final saved = await showNobSheet<bool>(
        context,
        child: _UploadSheet(fileName: picked.name, bytes: bytes),
      );
      if (saved == true && mounted) {
        ref.invalidate(documentsProvider);
        showNobSnack(context, 'Document uploaded.', tone: SnackTone.success);
      }
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _download(DocumentFile document) async {
    try {
      final bytes = await ref.read(documentRepositoryProvider).download(document);
      final target = await FilePicker.saveFile(
        dialogTitle: 'Save a copy',
        fileName: document.fileName,
        bytes: bytes,
        mimeType: document.mimeType,
      );
      if (target != null && mounted) {
        showNobSnack(context, 'Saved a copy.', tone: SnackTone.success);
      }
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  Future<void> _preview(DocumentFile document) async {
    try {
      final bytes = await ref.read(documentRepositoryProvider).download(document);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  NobSpace.xl,
                  NobSpace.md,
                  NobSpace.sm,
                  NobSpace.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        document.name,
                        style: NobText.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    semanticLabel: document.name,
                    errorBuilder: (_, _, _) => const Padding(
                      padding: EdgeInsets.all(NobSpace.xxl),
                      child: Text('This image could not be displayed.'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  Future<void> _delete(DocumentFile document) async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete ${document.name}?',
      message:
          'The file is removed from storage for everyone in the organization. '
          'This cannot be undone.',
      confirmLabel: 'Delete document',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(documentRepositoryProvider).delete(document);
      ref.invalidate(documentsProvider);
      if (mounted) showNobSnack(context, 'Document deleted.', tone: SnackTone.success);
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(canProvider(Permissions.documentsRead))) {
      return const PageScaffold(title: 'Documents', scrollable: false, child: NoAccessState());
    }
    final canWrite = ref.watch(canProvider(Permissions.documentsWrite));
    final canDelete = ref.watch(canProvider(Permissions.documentsDelete));
    final documents = ref.watch(documentsProvider(_filter));
    final filtered = _query.isNotEmpty || _category != null;

    return PageScaffold(
      title: 'Documents',
      subtitle: 'Contracts, receipts and records, private to your organization.',
      scrollable: false,
      actions: [
        if (canWrite)
          FilledButton.icon(
            onPressed: _picking ? null : _upload,
            icon: const Icon(Icons.upload_file_outlined, size: 18),
            label: const Text('Upload'),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SearchField(hint: 'Search by name', onChanged: (value) => setState(() => _query = value)),
          const SizedBox(height: NobSpace.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final category in <String?>[null, ...documentCategories])
                  Padding(
                    padding: const EdgeInsets.only(right: NobSpace.sm),
                    child: ChoiceChip(
                      label: Text(category == null ? 'All' : humanize(category)),
                      selected: _category == category,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: NobSpace.lg),
          Expanded(
            child: AsyncView(
              value: documents,
              onRetry: () => ref.invalidate(documentsProvider),
              builder: (items) {
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.folder_open_outlined,
                    title: filtered ? 'No matches' : 'No documents yet',
                    message: filtered
                        ? 'No document matches the current search or category.'
                        : 'Upload PDFs, images, spreadsheets and text files up to 20 MB. '
                              'Only members of this organization with access can open them.',
                    action: !filtered && canWrite
                        ? FilledButton(onPressed: _upload, child: const Text('Upload a document'))
                        : null,
                  );
                }
                return ListPanel(
                  itemCount: items.length,
                  footer: items.length >= listPageSize
                      ? const Text(
                          'Showing the most recent $listPageSize documents. Search to narrow the list.',
                        )
                      : null,
                  itemBuilder: (context, index) {
                    final document = items[index];
                    final created = document.createdAt;
                    return ListRow(
                      leading: RowIcon(
                        document.isPdf
                            ? Icons.picture_as_pdf_outlined
                            : document.isImage
                            ? Icons.image_outlined
                            : Icons.insert_drive_file_outlined,
                      ),
                      title: document.name,
                      subtitle: [
                        humanize(document.category),
                        formatFileSize(document.sizeBytes),
                        if (created != null) formatDate(created),
                        ?document.customerName,
                      ].join(' · '),
                      trailing: MenuAnchor(
                        menuChildren: [
                          if (document.isImage)
                            MenuItemButton(
                              leadingIcon: const Icon(Icons.visibility_outlined, size: 18),
                              onPressed: () => _preview(document),
                              child: const Text('Preview'),
                            ),
                          MenuItemButton(
                            leadingIcon: const Icon(Icons.download_outlined, size: 18),
                            onPressed: () => _download(document),
                            child: const Text('Save a copy'),
                          ),
                          if (canWrite)
                            MenuItemButton(
                              leadingIcon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () async {
                                final saved = await showNobSheet<bool>(
                                  context,
                                  child: _EditSheet(document: document),
                                );
                                if (saved == true) ref.invalidate(documentsProvider);
                              },
                              child: const Text('Rename or refile'),
                            ),
                          if (canDelete)
                            MenuItemButton(
                              leadingIcon: const Icon(Icons.delete_outline_rounded, size: 18),
                              onPressed: () => _delete(document),
                              child: const Text('Delete'),
                            ),
                        ],
                        builder: (context, controller, _) => IconButton(
                          tooltip: 'Actions for ${document.name}',
                          icon: const Icon(Icons.more_vert_rounded),
                          onPressed: () =>
                              controller.isOpen ? controller.close() : controller.open(),
                        ),
                      ),
                      onTap: () => document.isImage ? _preview(document) : _download(document),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Category dropdown shared by the upload and edit sheets.
class _CategoryField extends StatelessWidget {
  const _CategoryField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Category'),
      items: [
        for (final category in documentCategories)
          DropdownMenuItem(value: category, child: Text(humanize(category))),
      ],
      onChanged: (selected) => onChanged(selected ?? value),
    );
  }
}

class _UploadSheet extends ConsumerStatefulWidget {
  const _UploadSheet({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;

  @override
  ConsumerState<_UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends ConsumerState<_UploadSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: _withoutExtension(widget.fileName));
  final _notes = TextEditingController();
  String _category = documentCategories.first;
  Customer? _customer;
  bool _saving = false;
  String? _error;

  static String _withoutExtension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot > 0 ? fileName.substring(0, dot) : fileName;
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
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
      await ref
          .read(documentRepositoryProvider)
          .upload(
            organizationId: organizationId,
            workspaceId: ref.read(activeWorkspaceProvider)?.id,
            fileName: widget.fileName,
            bytes: widget.bytes,
            name: _name.text,
            category: _category,
            customerId: _customer?.id,
            notes: nullIfBlank(_notes.text),
          );
      if (mounted) Navigator.of(context).pop(true);
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
    final canPickCustomer = ref.watch(canProvider(Permissions.customersRead));
    return SheetScaffold(
      title: 'Upload document',
      subtitle: '${widget.fileName} · ${formatFileSize(widget.bytes.length)}',
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        PrimaryButton(label: 'Upload', onPressed: _save, loading: _saving),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) => Validators.length(value, min: 1, max: 200, label: 'Name'),
            ),
            const SizedBox(height: NobSpace.lg),
            _CategoryField(
              value: _category,
              onChanged: (value) => setState(() => _category = value),
            ),
            if (canPickCustomer) ...[
              const SizedBox(height: NobSpace.lg),
              CustomerField(
                customer: _customer,
                optional: true,
                onPick: () async {
                  final picked = await showCustomerPicker(context);
                  if (picked != null && mounted) setState(() => _customer = picked);
                },
                onClear: () => setState(() => _customer = null),
              ),
            ],
            const SizedBox(height: NobSpace.lg),
            TextFormField(
              controller: _notes,
              maxLength: 1000,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes (optional)', counterText: ''),
            ),
            if (error != null) ...[const SizedBox(height: NobSpace.lg), FormMessage(error)],
          ],
        ),
      ),
    );
  }
}

class _EditSheet extends ConsumerStatefulWidget {
  const _EditSheet({required this.document});

  final DocumentFile document;

  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.document.name);
  late final _notes = TextEditingController(text: widget.document.notes);
  late String _category = widget.document.category;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(documentRepositoryProvider)
          .update(
            widget.document.id,
            name: _name.text,
            category: _category,
            notes: nullIfBlank(_notes.text),
          );
      if (mounted) Navigator.of(context).pop(true);
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
      title: 'Document details',
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        PrimaryButton(label: 'Save', onPressed: _save, loading: _saving),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) => Validators.length(value, min: 1, max: 200, label: 'Name'),
            ),
            const SizedBox(height: NobSpace.lg),
            _CategoryField(
              value: _category,
              onChanged: (value) => setState(() => _category = value),
            ),
            const SizedBox(height: NobSpace.lg),
            TextFormField(
              controller: _notes,
              maxLength: 1000,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes (optional)', counterText: ''),
            ),
            if (error != null) ...[const SizedBox(height: NobSpace.lg), FormMessage(error)],
          ],
        ),
      ),
    );
  }
}
