import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider).auth),
);

/// The current session, kept up to date for the lifetime of the app.
final sessionProvider = StreamProvider<AuthSession?>((ref) async* {
  final repository = ref.watch(authRepositoryProvider);
  yield repository.currentSession;
  yield* repository.sessionChanges();
});

/// Id of the signed-in user, or null. Tenant state is keyed on this so that
/// nothing from one account survives into the next.
final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(sessionProvider.select((session) => session.value?.userId)),
);
