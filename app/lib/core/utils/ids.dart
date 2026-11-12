import 'dart:math';

final Random _random = Random.secure();

/// RFC 4122 version 4 UUID from the platform CSPRNG.
String newUuid() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Keeps a user-supplied file name safe to use as one storage path segment.
String safeFileName(String name) {
  final cleaned = name.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  final trimmed = cleaned.replaceAll(RegExp(r'^[._]+'), '');
  if (trimmed.isEmpty) return 'file';
  return trimmed.length > 120 ? trimmed.substring(trimmed.length - 120) : trimmed;
}
