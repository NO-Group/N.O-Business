import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design_system/components/brand_mark.dart';
import '../core/design_system/components/state_views.dart';
import '../core/design_system/tokens.dart';
import '../core/errors/app_failure.dart';
import '../features/auth/application/auth_providers.dart';
import '../features/tenancy/application/tenancy_providers.dart';

/// Shown while the session and tenant context are being resolved.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandMark(size: 64, glow: true),
            SizedBox(height: NobSpace.xl),
            SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
          ],
        ),
      ),
    );
  }
}

/// Shown when the user is signed in but their organizations could not be
/// loaded (offline, backend unavailable).
class UnavailableScreen extends ConsumerWidget {
  const UnavailableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(myContextProvider).error;
    final message = error == null
        ? 'Your workspace could not be loaded.'
        : AppFailure.from(error).message;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ErrorState(message: message, onRetry: () => ref.invalidate(myContextProvider)),
            ),
            Padding(
              padding: const EdgeInsets.all(NobSpace.xl),
              child: TextButton(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                child: const Text('Sign out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown for a path that matches no route.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key, required this.onHome});

  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EmptyState(
        icon: Icons.explore_off_outlined,
        title: 'Page not found',
        message: 'That address does not lead anywhere in N.O Business.',
        action: FilledButton(onPressed: onHome, child: const Text('Go to dashboard')),
      ),
    );
  }
}
