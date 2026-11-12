import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../tenancy/application/tenancy_providers.dart';
import '../data/document_repository.dart';
import '../domain/document_file.dart';

final documentRepositoryProvider = Provider<DocumentRepository>(
  (ref) => DocumentRepository(ref.watch(supabaseClientProvider)),
);

typedef DocumentQuery = ({String query, String? category});

/// Documents of the active organization matching a search and category.
final documentsProvider =
    FutureProvider.autoDispose.family<List<DocumentFile>, DocumentQuery>((ref, filter) async {
  final organizationId = ref.watch(activeOrganizationIdProvider);
  if (organizationId == null) return const [];
  return ref
      .watch(documentRepositoryProvider)
      .list(organizationId, query: filter.query, category: filter.category);
});
