import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/components/page_scaffold.dart';
import '../../../core/design_system/tokens.dart';
import '../../tenancy/application/tenancy_providers.dart';
import '../../tenancy/domain/permissions.dart';
import 'organization_settings.dart';
import 'profile_settings.dart';
import 'workspace_settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canOrg = ref.watch(canProvider(Permissions.orgManage));
    final canWorkspaces = ref.watch(canProvider(Permissions.workspacesManage));

    final tabs = <(String, Widget)>[
      ('Your account', const ProfileSettings()),
      ('Organization', OrganizationSettings(editable: canOrg)),
      ('Workspaces', WorkspaceSettings(editable: canWorkspaces)),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: PageScaffold(
        title: 'Settings',
        subtitle: 'Your account, the organization and its workspaces.',
        scrollable: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [for (final (label, _) in tabs) Tab(text: label)],
            ),
            const SizedBox(height: NobSpace.lg),
            Expanded(
              child: TabBarView(
                children: [
                  for (final (_, view) in tabs)
                    SingleChildScrollView(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: view),
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
