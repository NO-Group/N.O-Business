import '../../../core/utils/json.dart';

class Member {
  const Member({
    required this.membershipId,
    required this.userId,
    required this.email,
    required this.fullName,
    required this.roleId,
    required this.roleName,
    required this.isOwner,
    required this.status,
    this.joinedAt,
  });

  factory Member.fromJson(JsonMap json) {
    final profile = asJsonMap(json['profile']);
    final role = asJsonMap(json['role']);
    return Member(
      membershipId: asString(json['id']),
      userId: asString(json['user_id']),
      email: asString(profile['email']),
      fullName: asString(profile['full_name']),
      roleId: asString(json['role_id']),
      roleName: asString(role['name'], 'Member'),
      isOwner: asBool(role['is_owner']),
      status: asString(json['status'], 'active'),
      joinedAt: asDateTime(json['created_at']),
    );
  }

  final String membershipId;
  final String userId;
  final String email;
  final String fullName;
  final String roleId;
  final String roleName;
  final bool isOwner;

  /// `active` or `suspended`.
  final String status;
  final DateTime? joinedAt;

  String get displayName => fullName.trim().isNotEmpty ? fullName.trim() : email;
  bool get isSuspended => status == 'suspended';
}

class Invitation {
  const Invitation({
    required this.id,
    required this.email,
    required this.roleName,
    this.expiresAt,
    this.createdAt,
  });

  factory Invitation.fromJson(JsonMap json) => Invitation(
        id: asString(json['id']),
        email: asString(json['email']),
        roleName: asString(asJsonMap(json['role'])['name'], 'Member'),
        expiresAt: asDateTime(json['expires_at']),
        createdAt: asDateTime(json['created_at']),
      );

  final String id;
  final String email;
  final String roleName;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  bool isExpired(DateTime now) => expiresAt?.isBefore(now) ?? false;
}

class Role {
  const Role({
    required this.id,
    required this.name,
    required this.description,
    required this.isSystem,
    required this.isOwner,
    required this.permissions,
  });

  factory Role.fromJson(JsonMap json) => Role(
        id: asString(json['id']),
        name: asString(json['name']),
        description: asString(json['description']),
        isSystem: asBool(json['is_system']),
        isOwner: asBool(json['is_owner']),
        permissions: {
          for (final row in asJsonList(json['role_permissions'])) asString(row['permission_key']),
        },
      );

  final String id;
  final String name;
  final String description;

  /// Built-in role; cannot be edited or deleted.
  final bool isSystem;
  final bool isOwner;
  final Set<String> permissions;
}

/// One entry of the permission catalogue.
class PermissionInfo {
  const PermissionInfo({required this.key, required this.module, required this.description});

  factory PermissionInfo.fromJson(JsonMap json) => PermissionInfo(
        key: asString(json['key']),
        module: asString(json['module']),
        description: asString(json['description']),
      );

  final String key;
  final String module;
  final String description;
}

class AuditEntry {
  const AuditEntry({required this.action, required this.entityType, this.actorId, this.createdAt});

  factory AuditEntry.fromJson(JsonMap json) => AuditEntry(
        action: asString(json['action']),
        entityType: asString(json['entity_type']),
        actorId: asStringOrNull(json['actor_id']),
        createdAt: asDateTime(json['created_at']),
      );

  /// What happened: `insert`, `update`, `delete` or a named operation such
  /// as `issue` or `void`.
  final String action;

  /// The kind of record it happened to (a table name).
  final String entityType;
  final String? actorId;
  final DateTime? createdAt;
}
