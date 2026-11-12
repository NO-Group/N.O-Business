import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/guard.dart';
import '../../../core/utils/json.dart';
import '../domain/dashboard_summary.dart';

class DashboardRepository {
  const DashboardRepository(this._client);

  final SupabaseClient _client;

  /// [workspaceId] null means the whole organization.
  Future<DashboardSummary> summary({
    required String organizationId,
    String? workspaceId,
    required int days,
  }) => guard('dashboard.summary', () async {
    final result = await _client.rpc<dynamic>(
      'dashboard_summary',
      params: {'p_org': organizationId, 'p_workspace_id': workspaceId, 'p_days': days},
    );
    return DashboardSummary.fromJson(asJsonMap(result));
  });
}
