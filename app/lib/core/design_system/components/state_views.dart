import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../errors/app_failure.dart';
import '../tokens.dart';

/// Centered progress indicator with an optional caption.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final caption = message;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NobSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            if (caption != null) ...[
              const SizedBox(height: NobSpace.lg),
              Text(caption, style: NobText.bodySmall.copyWith(color: NobColors.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Contextual empty state: says what belongs here and offers the next step.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final next = action;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(NobSpace.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: NobColors.cobalt.withValues(alpha: 0.12),
                  borderRadius: NobRadius.large,
                  border: Border.all(color: NobColors.cobalt.withValues(alpha: 0.35)),
                ),
                child: Icon(icon, size: 28, color: NobColors.cyan),
              ),
              const SizedBox(height: NobSpace.lg),
              Text(title, style: NobText.title, textAlign: TextAlign.center),
              const SizedBox(height: NobSpace.sm),
              Text(
                message,
                style: NobText.body.copyWith(color: NobColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              if (next != null) ...[const SizedBox(height: NobSpace.xl), next],
            ],
          ),
        ),
      ),
    );
  }
}

/// Error state with a retry affordance. Shows only user-safe text.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final retry = onRetry;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(NobSpace.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 36, color: NobColors.danger),
              const SizedBox(height: NobSpace.md),
              Text(message, style: NobText.body, textAlign: TextAlign.center),
              if (retry != null) ...[
                const SizedBox(height: NobSpace.lg),
                OutlinedButton.icon(
                  onPressed: retry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown in place of a module the active role may not open.
class NoAccessState extends StatelessWidget {
  const NoAccessState({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.lock_outline_rounded,
      title: 'No access',
      message:
          'Your role in this organization does not include this area. '
          'Ask an owner or administrator if you need it.',
    );
  }
}

/// Renders an [AsyncValue] with the standard loading and error states, so
/// every screen handles them the same way.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.builder, this.onRetry});

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => const LoadingView(),
      error: (error, _) => ErrorState(message: AppFailure.from(error).message, onRetry: onRetry),
    );
  }
}
