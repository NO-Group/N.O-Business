/// Core domain models — M1 skeleton (in-memory). M2 replaces persistence
/// with Drift (offline SQLite) and M3 adds Supabase/Mongo sync on top of
/// these same shapes (see /docs/SPEC.md §4).

enum ProductCategory { fire, safety, security, solar, automation }

enum PaymentMethod { cash, transfer, pos, credit }

enum TxnType { salePayment, creditSale, invoicePayment, milsPayment, expense, refund }

enum InvoiceStatus { unpaid, partial, paid, overdue }

enum MaintenanceAction { installation, refill, inspection, repair, calibration }

enum AdjustmentReason { restock, damage, correction, returnToSupplier }

class Product {
  final String id;
  final String name;
  final String brand;
  final ProductCategory category;
  final int costPrice;
  final int sellingPrice;
  final int qtyOnHand;
  final int reorderLevel;
  final String unit;
  final double? length;
  final String lengthUnit;
  final double? width;
  final String widthUnit;
  final double? size;
  final String sizeUnit;
  final double? weight;
  final String weightUnit;
  final List<String> imageUrls;
  final bool isService;

  const Product({
    required this.id,
    required this.name,
    this.brand = '',
    required this.category,
    required this.costPrice,
    required this.sellingPrice,
    required this.qtyOnHand,
    required this.reorderLevel,
    this.unit = 'pcs',
    this.length,
    this.lengthUnit = '',
    this.width,
    this.widthUnit = '',
    this.size,
    this.sizeUnit = '',
    this.weight,
    this.weightUnit = '',
    this.imageUrls = const [],
    this.isService = false,
  });

  bool get isLow => !isService && qtyOnHand <= reorderLevel;
  bool get isOutOfStock => !isService && qtyOnHand <= 0;
  Product copyWith({int? qtyOnHand}) => Product(
        id: id,
        name: name,
        brand: brand,
        category: category,
        costPrice: costPrice,
        sellingPrice: sellingPrice,
        qtyOnHand: qtyOnHand ?? this.qtyOnHand,
        reorderLevel: reorderLevel,
        unit: unit,
        length: length, lengthUnit: lengthUnit,
        width: width, widthUnit: widthUnit,
        size: size, sizeUnit: sizeUnit,
        weight: weight, weightUnit: weightUnit,
        imageUrls: imageUrls,
        isService: isService,
      );
}

class Customer {
  final String id;
  final String name;
  final bool isCorporate;
  final String phone;
  final String email;
  final String address;
  int creditBalance; // outstanding across invoices

  Customer({
    required this.id,
    required this.name,
    required this.isCorporate,
    required this.phone,
    required this.email,
    required this.address,
    this.creditBalance = 0,
  });
}

class SaleItem {
  final Product product;
  final int qty;
  final int unitPrice;
  SaleItem({required this.product, required this.qty, int? unitPrice})
      : unitPrice = unitPrice ?? product.sellingPrice;
  int get total => qty * unitPrice;
}

class Sale {
  final String id;
  final DateTime date;
  final Customer customer;
  final List<SaleItem> items;
  final int discount;
  final PaymentMethod method;
  bool get isCredit => method == PaymentMethod.credit;
  int get subtotal => items.fold(0, (s, i) => s + i.total);
  int get total => subtotal - discount;

  Sale({
    required this.id,
    required this.date,
    required this.customer,
    required this.items,
    this.discount = 0,
    required this.method,
  });
}

class Transaction {
  final String id;
  final DateTime date;
  final TxnType type;
  final int amount;
  final PaymentMethod method;
  final String reference; // sale id, invoice id or note

  const Transaction({
    required this.id,
    required this.date,
    required this.type,
    required this.amount,
    required this.method,
    required this.reference,
  });
  bool get isRefund => type == TxnType.refund;
  bool get isReceivable => type == TxnType.creditSale;
  bool get isPayment =>
      type == TxnType.salePayment ||
      type == TxnType.invoicePayment ||
      type == TxnType.milsPayment;
}

class Receipt {
  final String number; // MTK-REC-0001
  final DateTime date;
  final Customer customer;
  final int amount;
  final PaymentMethod method;
  final String forDoc; // sale id or invoice number
  final String signedBy;
  final String issuedBy;
  final String customerSignature; // data: URL — customer signs on the device

  const Receipt({
    required this.number,
    required this.date,
    required this.customer,
    required this.amount,
    required this.method,
    required this.forDoc,
    required this.signedBy,
    this.issuedBy = 'Admin',
    this.customerSignature = '',
  });
}

class Invoice {
  final String number; // MTK-INV-0001
  final DateTime issued;
  final DateTime due;
  final Customer customer;
  final List<SaleItem> items;
  final int amountPaid;
  InvoiceStatus status(DateTime now) {
    if (amountPaid >= total) return InvoiceStatus.paid;
    if (now.isAfter(due)) return InvoiceStatus.overdue;
    if (amountPaid > 0) return InvoiceStatus.partial;
    return InvoiceStatus.unpaid;
  }

  int get total => items.fold(0, (s, i) => s + i.total);
  int get balance => total - amountPaid;
  const Invoice({
    required this.number,
    required this.issued,
    required this.due,
    required this.customer,
    required this.items,
    this.amountPaid = 0,
  });
}

class MaintenanceLog {
  final String id; // MTK-MILS-0001
  final DateTime serviceDate;
  final String equipment; // e.g. "DCP 6kg Fire Extinguisher ×24"
  final String? serial;
  final Customer client;
  final String location;
  final MaintenanceAction action;
  final String findings;
  final String technician;
  final DateTime nextDue;

  const MaintenanceLog({
    required this.id,
    required this.serviceDate,
    required this.equipment,
    this.serial,
    required this.client,
    required this.location,
    required this.action,
    required this.findings,
    required this.technician,
    required this.nextDue,
  });
  bool isOverdue(DateTime now) => now.isAfter(nextDue);
}

class StockAdjustment {
  final String id;
  final DateTime date;
  final Product product;
  final int delta; // +/- qty
  final AdjustmentReason reason;
  final String note;
  const StockAdjustment({
    required this.id,
    required this.date,
    required this.product,
    required this.delta,
    required this.reason,
    required this.note,
  });
}

/// Who has read a notification/announcement — used to show the sender a
/// per-recipient read receipt list, not just a count.
class NotificationRead {
  final String uid;
  final String name;
  final DateTime at;
  const NotificationRead({required this.uid, required this.name, required this.at});

  Map<String, dynamic> toJson() => {'uid': uid, 'name': name, 'at': at.toIso8601String()};
  factory NotificationRead.fromJson(Map<String, dynamic> j) => NotificationRead(
        uid: '${j['uid'] ?? ''}',
        name: '${j['name'] ?? ''}',
        at: DateTime.tryParse('${j['at']}') ?? DateTime.now(),
      );
}

/// An in-app notification: fired automatically for every significant write
/// (sale, invoice payment, document issue, stock change, new customer, new
/// product, MILS job, staff role change) OR composed manually by CEO/Admin
/// as an announcement. Every signed-in user (CEO, Admin, Sales) receives it.
class AppNotification {
  final String id;
  final String kind; // transaction | document | stock | customer | product | mils | staff | announcement
  final String title;
  final String message;
  final String ref;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;
  final List<NotificationRead> readBy;

  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.message,
    required this.ref,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    required this.readBy,
  });

  bool isReadBy(String uid) => readBy.any((r) => r.uid == uid);

  Map<String, dynamic> toJson() => {
        '_id': id, 'kind': kind, 'title': title, 'message': message, 'ref': ref,
        'created_by': createdBy, 'created_by_name': createdByName,
        'created_at': createdAt.toIso8601String(),
        'read_by': readBy.map((r) => r.toJson()).toList(),
      };
  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: '${j['_id'] ?? ''}',
        kind: '${j['kind'] ?? ''}',
        title: '${j['title'] ?? ''}',
        message: '${j['message'] ?? ''}',
        ref: '${j['ref'] ?? ''}',
        createdBy: '${j['created_by'] ?? ''}',
        createdByName: '${j['created_by_name'] ?? ''}',
        createdAt: DateTime.tryParse('${j['created_at']}') ?? DateTime.now(),
        readBy: [
          for (final r in (j['read_by'] as List? ?? const []))
            if (r is Map) NotificationRead.fromJson(r.cast<String, dynamic>()),
        ],
      );
}

/// A staff directory row for the CEO/Admin "Staff" screen — email + phone
/// visible to both roles; only the CEO can change `role` via the API.
class StaffMember {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role; // ceo | admin | sales
  final String staffId;
  final DateTime? createdAt;
  final String passportPhoto;

  const StaffMember({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.staffId = '',
    this.createdAt,
    this.passportPhoto = '',
  });

  factory StaffMember.fromJson(Map<String, dynamic> j) => StaffMember(
        uid: '${j['uid'] ?? ''}',
        name: '${j['name'] ?? ''}',
        email: '${j['email'] ?? ''}',
        phone: '${j['phone'] ?? ''}',
        role: '${j['role'] ?? 'sales'}',
        staffId: '${j['staff_id'] ?? ''}',
        createdAt: DateTime.tryParse('${j['created_at'] ?? ''}'),
        passportPhoto: '${j['passport_photo'] ?? ''}',
      );
}
