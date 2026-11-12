import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design_system/theme.dart';
import '../core/supabase/supabase_providers.dart';
import 'configuration_screen.dart';
import 'router.dart';

/// Root widget.
class NobApp extends ConsumerWidget {
  const NobApp({super.key});

  static const title = 'N.O Business';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final theme = buildNobTheme();

    final problem = config.problem;
    if (problem != null) {
      // Without a backend there is nothing to route to.
      return MaterialApp(
        title: title,
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: ConfigurationScreen(problem: problem),
      );
    }

    return MaterialApp.router(
      title: title,
      debugShowCheckedModeBanner: false,
      theme: theme,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
