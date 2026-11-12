import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_business/core/errors/app_failure.dart';
import 'package:no_business/core/supabase/query_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AppFailure.from', () {
    test('passes through messages our database functions raise for users', () {
      final failure = AppFailure.from(
        const PostgrestException(message: 'An invoice needs at least one line.', code: 'P0001'),
      );
      expect(failure.message, 'An invoice needs at least one line.');
      expect(failure.kind, FailureKind.validation);
    });

    test('never shows Postgres permission internals', () {
      for (final message in [
        'permission denied for table invoices',
        'new row violates row-level security policy for table "customers"',
        'Permission denied: invoices.write',
      ]) {
        final failure = AppFailure.from(PostgrestException(message: message, code: '42501'));
        expect(failure.kind, FailureKind.forbidden, reason: message);
        expect(failure.message, 'You do not have permission to do that.', reason: message);
      }
    });

    test('keeps readable refusals raised with the permission code', () {
      final failure = AppFailure.from(
        const PostgrestException(
          message: 'The last owner cannot leave the organization.',
          code: '42501',
        ),
      );
      expect(failure.message, 'The last owner cannot leave the organization.');
      expect(failure.kind, FailureKind.forbidden);
    });

    test('replaces constraint details with neutral sentences', () {
      final unique = AppFailure.from(
        const PostgrestException(
          message: 'duplicate key value violates unique constraint "products_sku_key"',
          code: '23505',
        ),
      );
      expect(unique.kind, FailureKind.conflict);
      expect(unique.message, isNot(contains('products_sku_key')));

      final check = AppFailure.from(
        const PostgrestException(
          message: 'violates check constraint "customers_phone_check"',
          code: '23514',
        ),
      );
      expect(check.kind, FailureKind.validation);
      expect(check.message, isNot(contains('customers_phone_check')));

      final unknown = AppFailure.from(
        const PostgrestException(message: 'relation "x" does not exist', code: '42P01'),
      );
      expect(unknown.kind, FailureKind.unknown);
      expect(unknown.message, isNot(contains('relation')));
    });

    test('treats timeouts as connectivity problems', () {
      expect(AppFailure.from(TimeoutException('slow')).kind, FailureKind.network);
    });

    test('maps storage refusals', () {
      expect(
        AppFailure.from(const StorageException('new row violates policy', statusCode: '403')).kind,
        FailureKind.forbidden,
      );
      expect(
        AppFailure.from(const StorageException('Payload too large', statusCode: '413')).message,
        'That file is too large.',
      );
    });

    test('returns an existing failure unchanged and hides unknown errors', () {
      const original = AppFailure('Already friendly', kind: FailureKind.validation);
      expect(identical(AppFailure.from(original), original), isTrue);
      final failure = AppFailure.from(StateError('internal detail'));
      expect(failure.message, isNot(contains('internal detail')));
    });
  });

  group('query utilities', () {
    test('likePattern strips characters with meaning in filters and patterns', () {
      expect(likePattern('acme'), '%acme%');
      expect(likePattern('  acme   ltd '), '%acme ltd%');
      expect(likePattern('100%_off'), '%100 off%');
      expect(likePattern('a,b(c)"d*'), '%a b c d%');
      expect(likePattern(r'back\slash'), '%back slash%');
    });

    test('requireAffected reports silently filtered writes as a permission failure', () {
      expect(() => requireAffected(const []), throwsA(isA<PostgrestException>()));
      expect(
        () => requireAffected(const [
          {'id': '1'},
        ]),
        returnsNormally,
      );
      try {
        requireAffected(const []);
      } on PostgrestException catch (error) {
        expect(AppFailure.from(error).kind, FailureKind.forbidden);
      }
    });
  });
}
