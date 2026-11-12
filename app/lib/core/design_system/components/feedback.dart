import 'package:flutter/material.dart';

import '../../errors/app_failure.dart';
import '../tokens.dart';
import 'buttons.dart';

enum SnackTone { neutral, success, danger }

/// Brief, non-blocking confirmation or error.
void showNobSnack(BuildContext context, String message, {SnackTone tone = SnackTone.neutral}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final IconData? icon;
  final Color color;
  switch (tone) {
    case SnackTone.neutral:
      icon = null;
      color = NobColors.textSecondary;
    case SnackTone.success:
      icon = Icons.check_circle_outline_rounded;
      color = NobColors.success;
    case SnackTone.danger:
      icon = Icons.error_outline_rounded;
      color = NobColors.danger;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: color),
              const SizedBox(width: NobSpace.md),
            ],
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

/// Shows the user-safe message for any thrown error.
void showFailure(BuildContext context, Object error) =>
    showNobSnack(context, AppFailure.from(error).message, tone: SnackTone.danger);

/// Confirmation for consequential actions. Resolves to true only on confirm.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message, style: NobText.body.copyWith(color: NobColors.textSecondary)),
      actionsPadding: const EdgeInsets.fromLTRB(NobSpace.xl, 0, NobSpace.xl, NobSpace.xl),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        if (destructive)
          DangerButton(label: confirmLabel, onPressed: () => Navigator.of(dialogContext).pop(true))
        else
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
      ],
    ),
  );
  return result ?? false;
}

/// Opens [child] as a dialog on wide layouts and a bottom sheet on phones.
Future<T?> showNobSheet<T>(BuildContext context, {required Widget child}) {
  if (NobBreakpoints.isCompact(context)) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: child,
      ),
    );
  }
  return showDialog<T>(
    context: context,
    builder: (dialogContext) => Dialog(
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: child),
    ),
  );
}

/// Standard frame for the content of [showNobSheet]: title, scrolling body,
/// pinned action row.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.title,
    required this.child,
    required this.actions,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(NobSpace.xl, NobSpace.xl, NobSpace.xl, NobSpace.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: NobText.title),
              if (sub != null) ...[
                const SizedBox(height: NobSpace.xs),
                Text(sub, style: NobText.bodySmall.copyWith(color: NobColors.textSecondary)),
              ],
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(NobSpace.xl, NobSpace.md, NobSpace.xl, NobSpace.lg),
            child: child,
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(NobSpace.lg),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: NobSpace.md,
            runSpacing: NobSpace.sm,
            children: actions,
          ),
        ),
      ],
    );
  }
}
