import 'package:flutter_test/flutter_test.dart';
import 'package:no_business/core/logging/app_logger.dart';
import 'package:no_business/core/utils/formatters.dart';
import 'package:no_business/core/utils/ids.dart';
import 'package:no_business/core/utils/validators.dart';

void main() {
  group('Validators', () {
    test('email', () {
      expect(Validators.email('ada@example.com'), isNull);
      expect(Validators.email('  ada@example.com '), isNull);
      expect(Validators.email('ada@'), isNotNull);
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('', optional: true), isNull);
    });

    test('phone accepts international format and ignores spacing', () {
      expect(Validators.phone('+234 801 234 5678'), isNull);
      expect(Validators.phone(''), isNull);
      expect(Validators.phone('08012345678'), isNotNull);
      expect(Validators.normalizePhone('+234 (801) 234-5678'), '+2348012345678');
    });

    test('password needs length, a letter and a digit', () {
      expect(Validators.password('short1'), isNotNull);
      expect(Validators.password('onlyletterslong'), isNotNull);
      expect(Validators.password('12345678901'), isNotNull);
      expect(Validators.password('correct horse 9'), isNull);
    });

    test('length and percentage bounds', () {
      expect(Validators.length('', min: 1, max: 5, label: 'Name'), 'Name is required');
      expect(Validators.length('abcdef', min: 1, max: 5), isNotNull);
      expect(Validators.length('abc', min: 1, max: 5), isNull);
      expect(Validators.percentage('7.5'), isNull);
      expect(Validators.percentage('101'), isNotNull);
      expect(Validators.percentage('-1'), isNotNull);
    });

    test('nullIfBlank', () {
      expect(nullIfBlank('   '), isNull);
      expect(nullIfBlank(null), isNull);
      expect(nullIfBlank(' x '), 'x');
    });
  });

  group('ids', () {
    test('newUuid is a version 4 UUID and does not repeat', () {
      final pattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      final seen = <String>{};
      for (var i = 0; i < 200; i++) {
        final id = newUuid();
        expect(pattern.hasMatch(id), isTrue, reason: id);
        expect(seen.add(id), isTrue);
      }
    });

    test('safeFileName keeps one harmless path segment', () {
      expect(safeFileName('Q3 report (final).pdf'), 'Q3_report_final_.pdf');
      expect(safeFileName('../../etc/passwd'), 'etc_passwd');
      expect(safeFileName('   '), 'file');
      expect(safeFileName('.hidden'), 'hidden');
      expect(safeFileName('a' * 300).length, 120);
    });
  });

  group('formatters', () {
    test('humanize and initials', () {
      expect(humanize('bank_transfer'), 'Bank transfer');
      expect(humanize(''), '');
      expect(initialsOf('Ada Lovelace'), 'AL');
      expect(initialsOf('ada'), 'A');
      expect(initialsOf('  '), '?');
    });

    test('dates and quantities', () {
      expect(toIsoDate(DateTime(2026, 3, 5)), '2026-03-05');
      expect(formatQuantity(1250), '1,250');
      expect(formatQuantity(2.5), '2.5');
    });
  });

  group('AppLogger', () {
    tearDown(() => AppLogger.sink = null);

    test('redacts credential-like fields, including nested ones', () {
      final safe = AppLogger.redact({
        'email': 'ada@example.com',
        'password': 'hunter2',
        'access_token': 'abc',
        'nested': <String, Object?>{'apiKey': 'k', 'count': 2},
      });
      expect(safe['email'], 'ada@example.com');
      expect(safe['password'], '[redacted]');
      expect(safe['access_token'], '[redacted]');
      expect((safe['nested']! as Map)['apiKey'], '[redacted]');
      expect((safe['nested']! as Map)['count'], 2);
    });

    test('emits structured records', () {
      final records = <Map<String, Object?>>[];
      AppLogger.sink = records.add;
      const AppLogger('test').info('hello', fields: {'refresh_token': 'x', 'rows': 3});
      expect(records, hasLength(1));
      expect(records.single['level'], 'info');
      expect(records.single['logger'], 'test');
      expect(records.single['message'], 'hello');
      expect(records.single['rows'], 3);
      expect(records.single['refresh_token'], '[redacted]');
      expect(records.single.containsKey('ts'), isTrue);
    });
  });
}
