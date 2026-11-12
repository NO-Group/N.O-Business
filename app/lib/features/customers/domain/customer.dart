import '../../../core/utils/json.dart';

class Customer {
  const Customer({
    required this.id,
    required this.organizationId,
    required this.kind,
    required this.name,
    this.email,
    this.phone,
    this.address,
    this.taxId,
    this.notes,
    this.createdAt,
  });

  factory Customer.fromJson(JsonMap json) => Customer(
        id: asString(json['id']),
        organizationId: asString(json['organization_id']),
        kind: asString(json['kind'], 'individual'),
        name: asString(json['name']),
        email: asStringOrNull(json['email']),
        phone: asStringOrNull(json['phone']),
        address: asStringOrNull(json['address']),
        taxId: asStringOrNull(json['tax_id']),
        notes: asStringOrNull(json['notes']),
        createdAt: asDateTime(json['created_at']),
      );

  final String id;
  final String organizationId;

  /// `individual` or `company`.
  final String kind;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final String? taxId;
  final String? notes;
  final DateTime? createdAt;

  bool get isCompany => kind == 'company';

  /// Email and phone on one line, whichever exist.
  String get contactLine => [?email, ?phone].join(' · ');
}

/// Editable fields of a customer, as sent to the database.
class CustomerInput {
  const CustomerInput({
    required this.kind,
    required this.name,
    this.email,
    this.phone,
    this.address,
    this.taxId,
    this.notes,
  });

  final String kind;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final String? taxId;
  final String? notes;

  JsonMap toJson() => {
        'kind': kind,
        'name': name.trim(),
        'email': email,
        'phone': phone,
        'address': address,
        'tax_id': taxId,
        'notes': notes,
      };
}
