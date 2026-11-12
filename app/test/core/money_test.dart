import 'package:flutter_test/flutter_test.dart';
import 'package:no_business/core/utils/money.dart';

void main() {
  group('Money.parse', () {
    test('converts typed amounts to minor units', () {
      expect(Money.parse('12500', 'NGN'), 1250000);
      expect(Money.parse('12,500.50', 'NGN'), 1250050);
      expect(Money.parse(' 1 000 ', 'USD'), 100000);
      expect(Money.parse('0', 'USD'), 0);
    });

    test('rounds instead of truncating binary fractions', () {
      // 19.99 * 100 is 1998.9999999999998 in floating point.
      expect(Money.parse('19.99', 'USD'), 1999);
      expect(Money.parse('0.07', 'USD'), 7);
    });

    test('respects currencies without minor units', () {
      expect(Money.fractionDigits('JPY'), 0);
      expect(Money.parse('1500', 'JPY'), 1500);
    });

    test('rejects text that is not a non-negative amount', () {
      expect(Money.parse('', 'NGN'), isNull);
      expect(Money.parse('abc', 'NGN'), isNull);
      expect(Money.parse('-5', 'NGN'), isNull);
      expect(Money.parse('1.2.3', 'NGN'), isNull);
      expect(Money.parse('1e5', 'NGN'), isNull);
    });
  });

  group('Money.format', () {
    test('renders minor units with separators and decimals', () {
      expect(Money.format(1250050, 'USD'), r'$12,500.50');
      expect(Money.format(0, 'USD'), r'$0.00');
      expect(Money.format(1250050, 'NGN'), endsWith('12,500.50'));
    });

    test('round-trips through the input representation', () {
      expect(Money.toInput(1250050, 'NGN'), '12500.50');
      expect(Money.parse(Money.toInput(1250050, 'NGN'), 'NGN'), 1250050);
      expect(Money.toInput(1500, 'JPY'), '1500');
    });
  });
}
