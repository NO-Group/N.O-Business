import 'package:flutter_test/flutter_test.dart';
import 'package:no_business/features/billing/domain/billing_models.dart';
import 'package:no_business/features/dashboard/domain/dashboard_summary.dart';
import 'package:no_business/features/documents/domain/document_file.dart';
import 'package:no_business/features/team/domain/team_models.dart';

void main() {
  group('Invoice', () {
    Map<String, dynamic> row({
      String status = 'issued',
      String? dueDate = '2026-11-10',
      int paid = 0,
    }) => {
      'id': 'inv-1',
      'number': status == 'draft' ? null : 'INV-000007',
      'workspace_id': 'ws-1',
      'customer_id': 'c-1',
      'customer': {'name': 'Acme Ltd'},
      'status': status,
      'issue_date': '2026-11-01',
      'due_date': dueDate,
      'currency_code': 'NGN',
      'subtotal_minor': 100000,
      'discount_minor': 0,
      'tax_minor': 7500,
      'total_minor': 107500,
      'amount_paid_minor': paid,
    };

    test('reads a list row that carries no lines or payments', () {
      final invoice = Invoice.fromJson(row());
      expect(invoice.customerName, 'Acme Ltd');
      expect(invoice.items, isEmpty);
      expect(invoice.payments, isEmpty);
      expect(invoice.totals.totalMinor, 107500);
      expect(invoice.displayNumber, 'INV-000007');
    });

    test('a draft has no number', () {
      final invoice = Invoice.fromJson(row(status: 'draft'));
      expect(invoice.isDraft, isTrue);
      expect(invoice.isOpen, isFalse);
      expect(invoice.displayNumber, 'Draft invoice');
    });

    test('balance is the total less what was paid', () {
      final invoice = Invoice.fromJson(row(status: 'partially_paid', paid: 7500));
      expect(invoice.balanceMinor, 100000);
      expect(invoice.isOpen, isTrue);
    });

    test('is overdue only while open and after the due date', () {
      final today = DateTime(2026, 11, 12, 15, 30);
      expect(Invoice.fromJson(row()).isOverdue(today), isTrue);
      expect(Invoice.fromJson(row(dueDate: '2026-11-12')).isOverdue(today), isFalse);
      expect(Invoice.fromJson(row(dueDate: '2026-11-13')).isOverdue(today), isFalse);
      expect(Invoice.fromJson(row(status: 'paid')).isOverdue(today), isFalse);
      expect(Invoice.fromJson(row(status: 'void')).isOverdue(today), isFalse);
      expect(Invoice.fromJson(row(dueDate: null)).isOverdue(today), isFalse);
    });

    test('orders lines by position and payments newest first', () {
      final invoice = Invoice.fromJson({
        ...row(status: 'partially_paid', paid: 3000),
        'items': [
          {
            'description': 'B',
            'position': 2,
            'quantity': 1,
            'unit_price_minor': 1,
            'line_total_minor': 1,
          },
          {
            'description': 'A',
            'position': 1,
            'quantity': 1,
            'unit_price_minor': 1,
            'line_total_minor': 1,
          },
        ],
        'payments': [
          {'id': 'p1', 'amount_minor': 1000, 'method': 'cash', 'paid_at': '2026-11-02T10:00:00Z'},
          {'id': 'p2', 'amount_minor': 2000, 'method': 'card', 'paid_at': '2026-11-05T10:00:00Z'},
        ],
      });
      expect(invoice.items.map((item) => item.description), ['A', 'B']);
      expect(invoice.payments.map((payment) => payment.id), ['p2', 'p1']);
    });
  });

  group('Quotation', () {
    Quotation withStatus(String status) => Quotation.fromJson({
      'id': 'q-1',
      'number': 'QUO-000001',
      'workspace_id': 'ws-1',
      'customer_id': 'c-1',
      'status': status,
      'currency_code': 'NGN',
      'total_minor': 5000,
    });

    test('can be edited while draft or sent', () {
      expect(withStatus('draft').isEditable, isTrue);
      expect(withStatus('sent').isEditable, isTrue);
      expect(withStatus('accepted').isEditable, isFalse);
      expect(withStatus('converted').isEditable, isFalse);
    });

    test('can be converted once sent or accepted', () {
      expect(withStatus('draft').isConvertible, isFalse);
      expect(withStatus('sent').isConvertible, isTrue);
      expect(withStatus('accepted').isConvertible, isTrue);
      expect(withStatus('declined').isConvertible, isFalse);
      expect(withStatus('converted').isConvertible, isFalse);
    });
  });

  group('DashboardSummary', () {
    test('reads the summary returned by the database', () {
      final summary = DashboardSummary.fromJson({
        'currency_code': 'NGN',
        'period_days': 7,
        'sales_total_minor': 300000,
        'sales_count': 3,
        'payments_total_minor': 200000,
        'previous_collected_minor': 400000,
        'daily': [
          {'day': '2026-11-11', 'sales_minor': 300000, 'payments_minor': 0},
          {'day': '2026-11-12', 'sales_minor': 0, 'payments_minor': 200000},
        ],
        'top_products': [
          {'name': 'Widget', 'quantity': '4.5', 'total_minor': 300000},
        ],
        'payment_methods': [
          {'method': 'bank_transfer', 'total_minor': 200000},
        ],
      });
      expect(summary.collectedMinor, 500000);
      expect(summary.collectedChange, closeTo(0.25, 1e-9));
      expect(summary.hasActivity, isTrue);
      expect(summary.daily.last.totalMinor, 200000);
      expect(summary.topProducts.single.quantity, 4.5);
      expect(summary.paymentMethods.single.method, 'bank_transfer');
    });

    test('has no comparison without an earlier period and tolerates missing fields', () {
      final summary = DashboardSummary.fromJson(const {});
      expect(summary.collectedChange, isNull);
      expect(summary.hasActivity, isFalse);
      expect(summary.currencyCode, 'USD');
      expect(summary.daily, isEmpty);
    });
  });

  group('documents', () {
    test('accepts only the file types the bucket allows', () {
      expect(mimeTypeForFileName('Contract.PDF'), 'application/pdf');
      expect(mimeTypeForFileName('photo.final.jpeg'), 'image/jpeg');
      expect(mimeTypeForFileName('sheet.xlsx'), contains('spreadsheetml'));
      expect(mimeTypeForFileName('setup.exe'), isNull);
      expect(mimeTypeForFileName('page.html'), isNull);
      expect(mimeTypeForFileName('noextension'), isNull);
      expect(mimeTypeForFileName('trailingdot.'), isNull);
    });

    test('formats sizes', () {
      expect(formatFileSize(512), '512 B');
      expect(formatFileSize(320 * 1024), '320 KB');
      expect(formatFileSize(1468006), '1.4 MB');
    });

    test('reads a stored document', () {
      final document = DocumentFile.fromJson(const {
        'id': 'd-1',
        'name': 'Lease',
        'category': 'contract',
        'storage_path': 'org-1/d-1/lease-2026.pdf',
        'mime_type': 'application/pdf',
        'size_bytes': 2048,
        'customer': {'name': 'Acme Ltd'},
      });
      expect(document.isPdf, isTrue);
      expect(document.isImage, isFalse);
      expect(document.fileName, 'lease-2026.pdf');
      expect(document.customerName, 'Acme Ltd');
    });
  });

  group('team', () {
    test('a member falls back to the email when no name is set', () {
      final member = Member.fromJson(const {
        'id': 'm-1',
        'user_id': 'u-1',
        'role_id': 'r-1',
        'status': 'suspended',
        'profile': {'email': 'ada@example.com', 'full_name': '  '},
        'role': {'name': 'Manager', 'is_owner': false},
      });
      expect(member.displayName, 'ada@example.com');
      expect(member.isSuspended, isTrue);
      expect(member.roleName, 'Manager');
      expect(member.isOwner, isFalse);
    });

    test('a role collects its permission keys', () {
      final role = Role.fromJson(const {
        'id': 'r-1',
        'name': 'Cashier',
        'is_system': true,
        'role_permissions': [
          {'permission_key': 'sales.read'},
          {'permission_key': 'sales.create'},
        ],
      });
      expect(role.permissions, {'sales.read', 'sales.create'});
      expect(role.isSystem, isTrue);
      expect(role.isOwner, isFalse);
    });
  });
}
