import 'package:flutter_test/flutter_test.dart';
import 'package:no_business/core/commerce/line_item.dart';

void main() {
  const widget = DraftLine(
    description: 'Widget',
    quantity: 2,
    unitPriceMinor: 100000,
    taxRate: 7.5,
  );
  const service = DraftLine(
    description: 'Delivery',
    quantity: 1,
    unitPriceMinor: 50000,
    taxRate: 0,
  );

  group('DocumentTotals.preview', () {
    test('adds exclusive tax per line', () {
      final totals = DocumentTotals.preview(const [widget, service]);
      expect(totals.subtotalMinor, 250000);
      expect(totals.discountMinor, 0);
      expect(totals.taxMinor, 15000);
      expect(totals.totalMinor, 265000);
    });

    test('charges tax on the discounted amount', () {
      final totals = DocumentTotals.preview(const [widget, service], discountMinor: 50000);
      expect(totals.subtotalMinor, 250000);
      expect(totals.discountMinor, 50000);
      // 15,000.00 of tax scaled by the 200,000 / 250,000 that is still charged.
      expect(totals.taxMinor, 12000);
      expect(totals.totalMinor, 212000);
    });

    test('never discounts below zero', () {
      final totals = DocumentTotals.preview(const [service], discountMinor: 999999);
      expect(totals.discountMinor, 50000);
      expect(totals.taxMinor, 0);
      expect(totals.totalMinor, 0);
      expect(DocumentTotals.preview(const [service], discountMinor: -5).discountMinor, 0);
    });

    test('is zero for an empty document', () {
      final totals = DocumentTotals.preview(const []);
      expect(totals.subtotalMinor, 0);
      expect(totals.taxMinor, 0);
      expect(totals.totalMinor, 0);
    });

    test('rounds fractional quantities to whole minor units', () {
      const line = DraftLine(
        description: 'Rice (kg)',
        quantity: 1.333,
        unitPriceMinor: 999,
        taxRate: 0,
      );
      expect(line.lineTotalMinor, 1332);
    });
  });

  group('DraftLine', () {
    test('serializes the shape the database functions expect', () {
      const line = DraftLine(
        productId: 'p-1',
        description: '  Widget  ',
        quantity: 3,
        unitPriceMinor: 2500,
        taxRate: 7.5,
      );
      expect(line.toJson(), {
        'product_id': 'p-1',
        'description': 'Widget',
        'quantity': 3.0,
        'unit_price_minor': 2500,
        'tax_rate': 7.5,
      });
      expect(service.toJson().containsKey('product_id'), isFalse);
    });

    test('round-trips a stored line', () {
      final item = LineItem.fromJson(const {
        'product_id': 'p-9',
        'description': 'Cable',
        'quantity': '2.5',
        'unit_price_minor': 1200,
        'tax_rate': 5,
        'line_total_minor': 3000,
      });
      final draft = DraftLine.fromItem(item);
      expect(draft.productId, 'p-9');
      expect(draft.quantity, 2.5);
      expect(draft.taxRate, 5);
      expect(draft.lineTotalMinor, 3000);
    });
  });

  test('stored lines are ordered by position', () {
    final items = LineItem.listFromJson([
      {'description': 'second', 'position': 2},
      {'description': 'first', 'position': 1},
      {'description': 'third', 'position': 3},
    ]);
    expect(items.map((item) => item.description), ['first', 'second', 'third']);
    expect(LineItem.listFromJson(null), isEmpty);
  });
}
