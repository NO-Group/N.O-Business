import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:supabase_flutter/supabase_flutter.dart';

enum FailureKind { network, unauthenticated, forbidden, validation, conflict, notFound, unknown }

/// The one error type the presentation layer deals with.
///
/// [message] is always safe to show to a user: backend messages are passed
/// through only when the server raised them deliberately for that purpose
/// (SQLSTATE P0001 / 42501 / 28000 from our own functions); everything else
/// is replaced with a neutral sentence so table names, constraint names and
/// stack traces never reach the screen.
class AppFailure implements Exception {
  const AppFailure(this.message, {this.kind = FailureKind.unknown, this.code});

  final String message;
  final FailureKind kind;
  final String? code;

  static const _generic = 'Something went wrong. Please try again.';
  static const _offline = 'Cannot reach the server. Check your connection and try again.';
  static const _forbidden = 'You do not have permission to do that.';

  factory AppFailure.from(Object error) {
    if (error is AppFailure) return error;
    // A provider that depends on a failed provider reports the wrapped cause.
    if (error is ProviderException) return AppFailure.from(error.exception);
    if (error is PostgrestException) return _fromPostgrest(error);
    if (error is AuthException) return _fromAuth(error);
    if (error is StorageException) return _fromStorage(error);
    if (error is TimeoutException) {
      return const AppFailure(_offline, kind: FailureKind.network);
    }
    final type = error.runtimeType.toString();
    if (type.contains('SocketException') ||
        type.contains('ClientException') ||
        type.contains('HandshakeException') ||
        type.contains('HttpException')) {
      return const AppFailure(_offline, kind: FailureKind.network);
    }
    return const AppFailure(_generic);
  }

  static AppFailure _fromPostgrest(PostgrestException error) {
    final code = error.code ?? '';
    final message = error.message;
    switch (code) {
      case 'P0001':
        return AppFailure(message, kind: FailureKind.validation, code: code);
      case '28000':
        return AppFailure('Please sign in again.', kind: FailureKind.unauthenticated, code: code);
      case '42501':
        // Our functions raise readable sentences; Postgres' own 42501 texts
        // ("permission denied for table ...", RLS violations) are not for users.
        final ours = !message.startsWith('permission denied') &&
            !message.contains('row-level security') &&
            !message.startsWith('Permission denied:');
        return AppFailure(ours ? message : _forbidden, kind: FailureKind.forbidden, code: code);
      case '23505':
        return AppFailure('That value is already in use.', kind: FailureKind.conflict, code: code);
      case '23503':
        return AppFailure(
          'This record is linked to other records and cannot be removed.',
          kind: FailureKind.conflict,
          code: code,
        );
      case '23514':
      case '22P02':
      case '22003':
        return AppFailure('Some of the values entered are not allowed.',
            kind: FailureKind.validation, code: code);
      case 'PGRST116':
        return AppFailure('That record no longer exists.', kind: FailureKind.notFound, code: code);
      case 'PGRST301':
      case 'PGRST302':
        return AppFailure('Please sign in again.', kind: FailureKind.unauthenticated, code: code);
    }
    return AppFailure(_generic, code: code);
  }

  static AppFailure _fromAuth(AuthException error) {
    if (error is AuthRetryableFetchException) {
      return const AppFailure(_offline, kind: FailureKind.network);
    }
    final status = error.statusCode;
    if (status == '429') {
      return const AppFailure('Too many attempts. Please wait a moment and try again.',
          kind: FailureKind.validation, code: '429');
    }
    // GoTrue messages ("Invalid login credentials", "Email not confirmed",
    // "Password should be at least 8 characters") are written for end users.
    final message = error.message.trim();
    return AppFailure(message.isEmpty ? _generic : message,
        kind: FailureKind.unauthenticated, code: status);
  }

  static AppFailure _fromStorage(StorageException error) {
    switch (error.statusCode) {
      case '403':
      case '401':
        return AppFailure(_forbidden, kind: FailureKind.forbidden, code: error.statusCode);
      case '404':
        return const AppFailure('That file no longer exists.', kind: FailureKind.notFound, code: '404');
      case '409':
        return const AppFailure('A file with that name already exists.', kind: FailureKind.conflict, code: '409');
      case '413':
        return const AppFailure('That file is too large.', kind: FailureKind.validation, code: '413');
      case '415':
        return const AppFailure('That file type is not supported.', kind: FailureKind.validation, code: '415');
    }
    return AppFailure(_generic, code: error.statusCode);
  }

  @override
  String toString() => 'AppFailure(${kind.name}, $code): $message';
}
