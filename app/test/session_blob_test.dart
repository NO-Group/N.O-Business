import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mtek_inventory/data/session_blob.dart';

/// Regression tests for the "logged-in user is signed out after reopening the
/// app" bug. The session blob is kept in TWO copies (OS credential vault and
/// app-private JSON) and restore must survive any single copy being missing,
/// corrupt or token-less.
void main() {
  const token = 'rt-AAA.BBB.CCC';

  Map<String, dynamic> full(String value, {String email = 'boss@mtek.ng'}) => {
        'refresh_token': value,
        'email': email,
        'name': 'M-Tek CEO',
        'role': 'ceo',
        'saved_at': '2026-11-04T09:00:00Z',
      };

  Map<String, dynamic>? decodeMap(String? raw) => SessionBlob.decode(raw);

  group('SessionBlob.decode', () {
    test('reads a healthy session blob', () {
      final parsed = decodeMap(jsonEncode(full(token)));
      expect(parsed?['refresh_token'], token);
      expect(parsed?['email'], 'boss@mtek.ng');
    });

    test('one corrupt / empty / missing copy never throws or hides the other', () {
      expect(decodeMap(null), isNull);
      expect(decodeMap(''), isNull);
      expect(decodeMap('   '), isNull);
      expect(decodeMap('{"refresh_token":'), isNull);
      expect(decodeMap('[]'), isNull);
      expect(decodeMap('null'), isNull);
      expect(decodeMap('42'), isNull);
    });
  });

  group('SessionBlob.refreshTokens', () {
    test('keeps distinct usable tokens, vault copy first', () {
      expect(
        SessionBlob.refreshTokens(<Map<String, dynamic>>[
          full('vault-token'),
          full('local-token'),
          full('vault-token'),
        ]),
        ['vault-token', 'local-token'],
      );
    });

    test('skips identity-only blobs and malformed tokens', () {
      expect(
        SessionBlob.refreshTokens(<Map<String, dynamic>>[
          {'email': 'boss@mtek.ng', 'role': 'ceo'},
          full('bad token with spaces'),
          full('line\nbreak'),
          full(token),
        ]),
        [token],
      );
    });

    test('vault wiped: the local recovery copy still supplies the token', () {
      final blobs = <Map<String, dynamic>>[];
      for (final raw in <String?>['{broken vault json', jsonEncode(full(token))]) {
        final parsed = decodeMap(raw);
        if (parsed != null) blobs.add(parsed);
      }
      expect(SessionBlob.refreshTokens(blobs), [token]);
      expect(SessionBlob.identity(blobs)?['email'], 'boss@mtek.ng');
    });
  });

  group('SessionBlob.identity', () {
    test('legacy identity-only copy is enough to keep the user signed in', () {
      // This is the exact boot case that used to show the login screen:
      // secure storage was gone and the local file had no refresh token.
      const legacy = <String, dynamic>{
        'email': 'mtekfiresafetyltd@gmail.com',
        'name': 'CEO',
        'role': 'ceo',
      };
      final blobs = <Map<String, dynamic>>[{}, legacy];
      expect(SessionBlob.identity(blobs)?['email'], 'mtekfiresafetyltd@gmail.com');
      expect(SessionBlob.refreshTokens(blobs), isEmpty,
          reason: 'offline sign-in is still allowed when no token is present');
    });

    test('a complete copy wins over a stale identity-only copy', () {
      const legacy = <String, dynamic>{'email': 'x@y.com', 'role': 'sales'};
      expect(SessionBlob.identity(<Map<String, dynamic>>[legacy, full(token, email: 'x@y.com')])
          ?['refresh_token'], token);
    });

    test('no readable identity returns null without throwing', () {
      expect(SessionBlob.identity(<Map<String, dynamic>>[{}, {'refresh_token': token}]), isNull);
      expect(SessionBlob.identity(<Map<String, dynamic>>[]), isNull);
    });

    test('emails are canonicalised for the CEO lock', () {
      expect(SessionBlob.email({'email': '  MtekFireSafetyLtd@GMAIL.com '}),
          'mtekfiresafetyltd@gmail.com');
      expect(SessionBlob.email({'email': 'not-an-email'}), isNull);
      expect(SessionBlob.email(null), isNull);
    });
  });
}
