/// Build-time configuration. EVERYTHING is baked in: the apps (APK and
/// Windows EXE) ship pointing at the company's REAL server — a plain
/// `flutter build apk --release` needs no flags at all.
/// NOTE: the API lives at `data-api` — the original `data-api` function
/// name got a corrupted deployment cache on Supabase's edge (every new
/// deploy of it kept serving a days-old bundle; verified by canary bisect),
/// so the identical code now deploys under a fresh name.
/// (The anon key is a PUBLIC client key by design; all authority is
/// enforced server-side by the data API.)
abstract final class Env {

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://kshuadjcflwlidupnqly.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtzaHVhZGpjZmx3bGlkdXBucWx5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgwMjg4NjksImV4cCI6MjEwMzYwNDg2OX0.9uK8CK-5Xw9ojCAHKQyUEPVleSDJYcsznmHZETNyJ-I',
  );
  static const apiBase = String.fromEnvironment(
    'MILS_API_BASE',
    defaultValue: 'https://kshuadjcflwlidupnqly.supabase.co/functions/v1/data-api',
  );

  /// OFFLINE-ONLY switch. `true` disconnects the MongoDB data API entirely
  /// (used 2026-09-03 while Atlas auth was broken). `false` = normal
  /// offline-FIRST operation: the server is used when reachable, the local
  /// files otherwise, and every record made offline is uploaded through
  /// POST /api/sync/import the next time the API answers (see
  /// AppStore._uploadOfflineData).
  static const bool offlineDataMode = false;

  static bool get backendConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Data-API (MongoDB sections) available? FALSE in offline mode so every
  /// store/auth call takes its existing local/offline branch.
  static bool get apiConfigured => !offlineDataMode && apiBase.isNotEmpty;

  /// Auth routes are still served by the same function URL, even offline.
  static bool get authApiConfigured => apiBase.isNotEmpty;
}
