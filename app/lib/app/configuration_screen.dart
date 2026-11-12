import 'package:flutter/material.dart';

import '../core/design_system/components/brand_mark.dart';
import '../core/design_system/components/nob_card.dart';
import '../core/design_system/tokens.dart';

/// Shown when the build carries no usable backend configuration.
///
/// The app never ships with a baked-in backend, so a build made without the
/// `--dart-define` values lands here instead of failing obscurely.
class ConfigurationScreen extends StatelessWidget {
  const ConfigurationScreen({super.key, required this.problem});

  final String problem;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(NobSpace.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: NobCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandLockup(),
                  const SizedBox(height: NobSpace.xl),
                  const Text('This build is not connected to a backend', style: NobText.title),
                  const SizedBox(height: NobSpace.sm),
                  Text(problem, style: NobText.body.copyWith(color: NobColors.textSecondary)),
                  const SizedBox(height: NobSpace.lg),
                  Text(
                    'Build the app with the project URL and its public key:',
                    style: NobText.body.copyWith(color: NobColors.textSecondary),
                  ),
                  const SizedBox(height: NobSpace.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(NobSpace.md),
                    decoration: BoxDecoration(
                      color: NobColors.background,
                      borderRadius: NobRadius.small,
                      border: Border.all(color: NobColors.border),
                    ),
                    child: const SelectableText(
                      '--dart-define=SUPABASE_URL=…\n--dart-define=SUPABASE_ANON_KEY=…',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: NobColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
