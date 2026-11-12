import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/env.dart';
import 'core/logging/app_logger.dart';
import 'core/storage/app_preferences.dart';
import 'core/supabase/secure_session_storage.dart';
import 'core/supabase/supabase_providers.dart';

const _log = AppLogger('bootstrap');

/// Wires up error reporting, configuration, storage and the backend client,
/// then starts the widget tree.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _log.error('flutter framework error', error: details.exception, stackTrace: details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    _log.error('uncaught error', error: error, stackTrace: stackTrace);
    return true;
  };

  final config = AppConfig.fromEnvironment();
  const secureStorage = FlutterSecureStorage();
  final preferences = await AppPreferences.load(secureStorage);

  if (config.isUsable) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        localStorage: SecureSessionStorage(secureStorage),
        // Email codes are used instead of links; no URL handler is registered.
        detectSessionInUri: false,
      ),
      debug: false,
    );
    _log.info('started', fields: {'version': config.appVersion});
  } else {
    _log.warning('backend is not configured', fields: {'reason': config.problem});
  }

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        appPreferencesProvider.overrideWithValue(preferences),
      ],
      // Failed loads are retried by the user from the error state, not
      // silently in the background.
      retry: (_, _) => null,
      child: const NobApp(),
    ),
  );
}
