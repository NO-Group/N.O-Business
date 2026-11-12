import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/guard.dart';
import '../../../core/utils/json.dart';
import '../domain/team_models.dart';

class TeamRepository {
  const TeamRepository(this._client);

  final SupabaseClient _client;

  Future<List<Member>> members(String organizationId) => guard('team.members', () async {
        final rows = await _client
            .from('memberships')
            .select(
              'id, user_id, role_id, status, created_at, '
              'profile:profiles(email, full_name), role:roles(name, is_owner)',
            )
            .eq('organization_id', organizationId)
            .order('created_at');
        return rows.map(Member.fromJson).toList();
      });

  Future<List<Invitation>> pendingInvitations(String organizationId) => guard('team.invitations', () async {
        final rows = await _client
            .from('invitations')
            .select('id, email, expires_at, created_at, role:roles(name)')
            .eq('organization_id', organizationId)
            .eq('status', 'pending')
            .order('created_at', ascending: false);
        return rows.map(Invitation.fromJson).toList();
      });

  Future<List<Role>> roles(String organizationId) => guard('team.roles', () async {
        final rows = await _client
            .from('roles')
            .select('id, name, description, is_system, is_owner, role_permissions(permission_key)')
            .eq('organization_id', organizationId)
            .order('is_system', ascending: false)
            .order('name');
        return rows.map(Role.fromJson).toList();
      });

  Future<List<PermissionInfo>> permissionCatalogue() => guard('team.permissions', () async {
        final rows = await _client.from('permissions').select('key, module, description').order('key');
        return rows.map(PermissionInfo.fromJson).toList();
      });

  Future<List<AuditEntry>> auditTrail(String organizationId) => guard('team.audit', () async {
        final rows = await _client
            .from('audit_logs')
            .select('action, entity_type, actor_id, created_at')
            .eq('organization_id', organizationId)
            .order('created_at', ascending: false)
            .limit(100);
        return rows.map(AuditEntry.fromJson).toList();
      });

  Future<void> invite({required String organizationId, required String email, required String roleId}) =>
      guard('team.invite', () async {
        await _client.rpc<dynamic>(
          'invite_member',
          params: {'p_org': organizationId, 'p_email': email.trim().toLowerCase(), 'p_role_id': roleId},
        );
      });

  Future<void> revokeInvitation(String invitationId) => guard('team.revoke_invitation', () async {
        await _client.rpc<dynamic>('revoke_invitation', params: {'p_invitation_id': invitationId});
      });

  Future<void> setMemberRole(String membershipId, String roleId) => guard('team.set_role', () async {
        await _client.rpc<dynamic>(
          'set_member_role',
          params: {'p_membership_id': membershipId, 'p_role_id': roleId},
        );
      });

  Future<void> setMemberStatus(String membershipId, String status) => guard('team.set_status', () async {
        await _client.rpc<dynamic>(
          'set_member_status',
          params: {'p_membership_id': membershipId, 'p_status': status},
        );
      });

  Future<void> removeMember(String membershipId) => guard('team.remove', () async {
        await _client.rpc<dynamic>('remove_member', params: {'p_membership_id': membershipId});
      });

  /// Creates ([roleId] null) or updates a custom role. Returns its id.
  Future<String> saveRole({
    required String organizationId,
    required String name,
    required String description,
    required Set<String> permissions,
    String? roleId,
  }) =>
      guard('team.save_role', () async {
        final result = await _client.rpc<dynamic>('save_role', params: {
          'p_org': organizationId,
          'p_role_id': roleId,
          'p_name': name.trim(),
          'p_description': description.trim(),
          'p_permissions': permissions.toList()..sort(),
        });
        return asString(result);
      });

  Future<void> deleteRole(String roleId) => guard('team.delete_role', () async {
        await _client.rpc<dynamic>('delete_role', params: {'p_role_id': roleId});
      });
}
