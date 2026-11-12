import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../storage/app_preferences.dart';

/// Overridden in `bootstrap()` with the resolved build configuration.
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('appConfigProvider must be overridden at start-up'),
);

/// Overridden in `bootstrap()` once preferences have been read from disk.
final appPreferencesProvider = Provider<AppPreferences>(
  (ref) => throw UnimplementedError('appPreferencesProvider must be overridden at start-up'),
);

/// The single Supabase client. Only read when [AppConfig.isUsable] is true.
final supabaseClientProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);
