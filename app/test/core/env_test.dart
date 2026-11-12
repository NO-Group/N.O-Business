import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_business/core/config/env.dart';

String _jwt(Map<String, Object?> payload) {
  String part(Object value) => base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part(payload)}.signature';
}

void main() {
  group('Env.validate', () {
    final anon = _jwt({'role': 'anon', 'iss': 'supabase'});

    test('accepts an https project URL with a public key', () {
      expect(Env.validate(url: 'https://example.supabase.co', key: anon), isNull);
      expect(Env.validate(url: 'https://example.supabase.co', key: 'sb_publishable_abc'), isNull);
    });

    test('reports missing configuration', () {
      expect(Env.validate(url: '', key: anon), contains('not provided'));
      expect(Env.validate(url: 'https://example.supabase.co', key: ''), contains('not provided'));
    });

    test('rejects plain http except for local development', () {
      expect(Env.validate(url: 'http://example.com', key: anon), contains('https'));
      expect(Env.validate(url: 'http://localhost:54321', key: anon), isNull);
      expect(Env.validate(url: 'http://10.0.2.2:54321', key: anon), isNull);
    });

    test('rejects malformed URLs', () {
      expect(Env.validate(url: 'not a url', key: anon), isNotNull);
    });

    test('refuses privileged keys', () {
      final serviceRole = _jwt({'role': 'service_role', 'iss': 'supabase'});
      expect(Env.isPrivilegedKey(serviceRole), isTrue);
      expect(Env.isPrivilegedKey('sb_secret_abc'), isTrue);
      expect(Env.isPrivilegedKey(anon), isFalse);
      expect(Env.isPrivilegedKey('sb_publishable_abc'), isFalse);
      expect(Env.validate(url: 'https://example.supabase.co', key: serviceRole), contains('privileged'));
      expect(Env.validate(url: 'https://example.supabase.co', key: 'sb_secret_abc'), contains('privileged'));
    });

    test('treats an undecodable token as non-privileged rather than crashing', () {
      expect(Env.isPrivilegedKey('a.b.c'), isFalse);
      expect(Env.isPrivilegedKey('a.%%%.c'), isFalse);
    });
  });

  test('AppConfig exposes the validation result', () {
    const config = AppConfig(supabaseUrl: '', supabaseAnonKey: '', appVersion: 'test');
    expect(config.isUsable, isFalse);
    expect(config.problem, isNotNull);
  });
}
