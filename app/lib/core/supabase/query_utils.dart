import 'package:supabase_flutter/supabase_flutter.dart';

/// Largest number of rows a list screen asks for at once.
const int listPageSize = 200;

/// Turns free text typed into a search box into a safe `ilike` pattern.
///
/// Characters that carry meaning in PostgREST filter syntax or in LIKE
/// patterns are removed, so user input can never widen or break a filter.
String likePattern(String query) {
  final cleaned = query
      .replaceAll(RegExp(r'[,()"\\%*_]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return '%$cleaned%';
}

/// Row-level security filters rows silently: an UPDATE or DELETE the caller
/// may not perform simply matches nothing. Surface that as a permission
/// failure instead of pretending it worked.
void requireAffected(List<Map<String, dynamic>> rows) {
  if (rows.isEmpty) {
    throw const PostgrestException(
      message: 'You do not have permission to do that.',
      code: '42501',
    );
  }
}
