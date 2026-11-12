import '../../../core/utils/json.dart';

/// The signed-in person's own profile.
class UserProfile {
  const UserProfile({required this.id, required this.email, required this.fullName, this.phone});

  factory UserProfile.fromJson(JsonMap json) => UserProfile(
    id: asString(json['id']),
    email: asString(json['email']),
    fullName: asString(json['full_name']),
    phone: asStringOrNull(json['phone']),
  );

  final String id;
  final String email;
  final String fullName;
  final String? phone;

  /// Name to show; falls back to the mailbox name until one is set.
  String get displayName => fullName.trim().isNotEmpty ? fullName.trim() : email.split('@').first;
}

/// A tenant. Everything a business owns hangs off one of these.
class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.currencyCode,
    required this.timezone,
    this.slug = '',
    this.legalName,
    this.email,
    this.phone,
    this.address,
    this.countryCode,
    this.taxId,
    this.defaultTaxRate = 0,
    this.brandColor,
    this.logoPath,
    this.documentFooter,
  });

  factory Organization.fromJson(JsonMap json) => Organization(
    id: asString(json['id']),
    name: asString(json['name']),
    slug: asString(json['slug']),
    legalName: asStringOrNull(json['legal_name']),
    email: asStringOrNull(json['email']),
    phone: asStringOrNull(json['phone']),
    address: asStringOrNull(json['address']),
    countryCode: asStringOrNull(json['country_code']),
    currencyCode: asString(json['currency_code'], 'USD'),
    timezone: asString(json['timezone'], 'UTC'),
    taxId: asStringOrNull(json['tax_id']),
    defaultTaxRate: asDouble(json['default_tax_rate']),
    brandColor: asStringOrNull(json['brand_color']),
    logoPath: asStringOrNull(json['logo_path']),
    documentFooter: asStringOrNull(json['document_footer']),
  );

  final String id;
  final String name;
  final String slug;
  final String? legalName;
  final String? email;
  final String? phone;
  final String? address;
  final String? countryCode;
  final String currencyCode;
  final String timezone;
  final String? taxId;
  final double defaultTaxRate;
  final String? brandColor;
  final String? logoPath;
  final String? documentFooter;
}

class RoleRef {
  const RoleRef({required this.id, required this.name, this.isOwner = false});

  factory RoleRef.fromJson(JsonMap json) => RoleRef(
    id: asString(json['id']),
    name: asString(json['name']),
    isOwner: asBool(json['is_owner']),
  );

  final String id;
  final String name;
  final bool isOwner;
}

/// The signed-in person's place in one organization.
class OrgMembership {
  const OrgMembership({
    required this.membershipId,
    required this.organization,
    required this.role,
    required this.permissions,
  });

  factory OrgMembership.fromJson(JsonMap json) => OrgMembership(
    membershipId: asString(json['membership_id']),
    organization: Organization.fromJson(asJsonMap(json['organization'])),
    role: RoleRef.fromJson(asJsonMap(json['role'])),
    permissions: asStringList(json['permissions']).toSet(),
  );

  final String membershipId;
  final Organization organization;
  final RoleRef role;
  final Set<String> permissions;

  bool can(String permission) => permissions.contains(permission);
}

/// An invitation addressed to the signed-in person's verified email.
class PendingInvitation {
  const PendingInvitation({
    required this.id,
    required this.organizationName,
    required this.roleName,
    this.expiresAt,
  });

  factory PendingInvitation.fromJson(JsonMap json) => PendingInvitation(
    id: asString(json['id']),
    organizationName: asString(json['organization_name']),
    roleName: asString(json['role_name']),
    expiresAt: asDateTime(json['expires_at']),
  );

  final String id;
  final String organizationName;
  final String roleName;
  final DateTime? expiresAt;
}

/// Everything the app needs to know about the caller, from `get_my_context`.
class MyContext {
  const MyContext({required this.profile, required this.memberships, required this.invitations});

  factory MyContext.fromJson(JsonMap json) => MyContext(
    profile: UserProfile.fromJson(asJsonMap(json['profile'])),
    memberships: asJsonList(json['memberships']).map(OrgMembership.fromJson).toList(),
    invitations: asJsonList(json['invitations']).map(PendingInvitation.fromJson).toList(),
  );

  final UserProfile profile;
  final List<OrgMembership> memberships;
  final List<PendingInvitation> invitations;
}

/// A branch / location inside an organization. Stock, sales and billing
/// documents belong to a workspace; customers and the catalogue do not.
class Workspace {
  const Workspace({
    required this.id,
    required this.organizationId,
    required this.name,
    this.address,
    this.isDefault = false,
    this.isArchived = false,
  });

  factory Workspace.fromJson(JsonMap json) => Workspace(
    id: asString(json['id']),
    organizationId: asString(json['organization_id']),
    name: asString(json['name']),
    address: asStringOrNull(json['address']),
    isDefault: asBool(json['is_default']),
    isArchived: asBool(json['is_archived']),
  );

  final String id;
  final String organizationId;
  final String name;
  final String? address;
  final bool isDefault;
  final bool isArchived;
}

/// Values collected when a new organization is created.
class NewOrganization {
  const NewOrganization({
    required this.name,
    required this.currencyCode,
    required this.countryCode,
    required this.timezone,
    required this.workspaceName,
  });

  final String name;
  final String currencyCode;
  final String? countryCode;
  final String timezone;
  final String workspaceName;
}
