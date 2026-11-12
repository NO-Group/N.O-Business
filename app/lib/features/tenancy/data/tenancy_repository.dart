import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/guard.dart';
import '../../../core/supabase/query_utils.dart';
import '../../../core/utils/json.dart';
import '../domain/models.dart';

/// Organizations, workspaces and the caller's own profile.
class TenancyRepository {
  const TenancyRepository(this._client);

  final SupabaseClient _client;

  Future<MyContext> fetchContext() => guard('tenancy.context', () async {
        final result = await _client.rpc<dynamic>('get_my_context');
        return MyContext.fromJson(asJsonMap(result));
      });

  /// Creates an organization with its first workspace and makes the caller
  /// its owner. Returns the new organization id.
  Future<String> createOrganization(NewOrganization input) => guard('tenancy.create_org', () async {
        final result = await _client.rpc<dynamic>('create_organization', params: {
          'p_name': input.name,
          'p_currency_code': input.currencyCode,
          'p_country_code': input.countryCode,
          'p_timezone': input.timezone,
          'p_workspace_name': input.workspaceName,
        });
        return asString(result);
      });

  /// Returns the id of the organization that was joined.
  Future<String> acceptInvitation(String invitationId) => guard('tenancy.accept_invitation', () async {
        final result = await _client
            .rpc<dynamic>('accept_invitation', params: {'p_invitation_id': invitationId});
        return asString(result);
      });

  Future<void> leaveOrganization(String organizationId) => guard('tenancy.leave_org', () async {
        await _client.rpc<dynamic>('leave_organization', params: {'p_org': organizationId});
      });

  /// [changes] may only contain the columns the database lets clients edit.
  Future<void> updateOrganization(String organizationId, JsonMap changes) =>
      guard('tenancy.update_org', () async {
        final rows = await _client.from('organizations').update(changes).eq('id', organizationId).select('id');
        requireAffected(rows);
      });

  Future<void> updateProfile({required String userId, required String fullName, String? phone}) =>
      guard('tenancy.update_profile', () async {
        final rows = await _client
            .from('profiles')
            .update({'full_name': fullName, 'phone': phone})
            .eq('id', userId)
            .select('id');
        requireAffected(rows);
      });

  Future<List<Workspace>> listWorkspaces(String organizationId) => guard('tenancy.workspaces', () async {
        final rows = await _client
            .from('workspaces')
            .select()
            .eq('organization_id', organizationId)
            .order('is_default', ascending: false)
            .order('name');
        return rows.map(Workspace.fromJson).toList();
      });

  Future<void> createWorkspace({required String organizationId, required String name, String? address}) =>
      guard('tenancy.create_workspace', () async {
        await _client
            .from('workspaces')
            .insert({'organization_id': organizationId, 'name': name, 'address': address});
      });

  Future<void> editWorkspace(String workspaceId, {required String name, String? address}) =>
      guard('tenancy.edit_workspace', () async {
        final rows = await _client
            .from('workspaces')
            .update({'name': name, 'address': address})
            .eq('id', workspaceId)
            .select('id');
        requireAffected(rows);
      });

  Future<void> setWorkspaceArchived(String workspaceId, {required bool archived}) =>
      guard('tenancy.archive_workspace', () async {
        final rows = await _client
            .from('workspaces')
            .update({'is_archived': archived})
            .eq('id', workspaceId)
            .select('id');
        requireAffected(rows);
      });

  Future<void> setDefaultWorkspace(String workspaceId) => guard('tenancy.default_workspace', () async {
        await _client.rpc<dynamic>('set_default_workspace', params: {'p_workspace_id': workspaceId});
      });
}
