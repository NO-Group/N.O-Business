import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/guard.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/query_utils.dart';
import '../../../core/utils/ids.dart';
import '../domain/document_file.dart';

const _log = AppLogger('documents');
const _bucket = 'documents';

class DocumentRepository {
  const DocumentRepository(this._client);

  final SupabaseClient _client;

  static const _columns = 'id, name, category, storage_path, mime_type, size_bytes, customer_id, notes, '
      'created_at, customer:customers(name)';

  Future<List<DocumentFile>> list(String organizationId, {String query = '', String? category}) =>
      guard('documents.list', () async {
        var request = _client.from('documents').select(_columns).eq('organization_id', organizationId);
        if (category != null) request = request.eq('category', category);
        if (query.trim().isNotEmpty) request = request.ilike('name', likePattern(query));
        final rows = await request.order('created_at', ascending: false).limit(listPageSize);
        return rows.map(DocumentFile.fromJson).toList();
      });

  /// Stores the file in the organization's private folder, then records it.
  ///
  /// The object key is `<organization>/<document>/<file name>`; storage
  /// policies only accept keys inside an organization the caller may write
  /// documents for, and the table only accepts a row that points into its own
  /// folder. If recording fails the uploaded object is removed again.
  Future<void> upload({
    required String organizationId,
    required String fileName,
    required Uint8List bytes,
    required String name,
    required String category,
    String? workspaceId,
    String? customerId,
    String? notes,
  }) =>
      guard('documents.upload', () async {
        final mimeType = mimeTypeForFileName(fileName);
        if (mimeType == null) {
          throw const AppFailure('That file type is not supported.', kind: FailureKind.validation);
        }
        if (bytes.isEmpty || bytes.length > maxDocumentBytes) {
          throw const AppFailure('Files can be up to 20 MB.', kind: FailureKind.validation);
        }
        final id = newUuid();
        final path = '$organizationId/$id/${safeFileName(fileName)}';
        final storage = _client.storage.from(_bucket);
        await storage.uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mimeType));
        try {
          await _client.from('documents').insert({
            'id': id,
            'organization_id': organizationId,
            'workspace_id': workspaceId,
            'name': name.trim(),
            'category': category,
            'storage_path': path,
            'mime_type': mimeType,
            'size_bytes': bytes.length,
            'customer_id': customerId,
            'notes': notes,
          });
        } catch (_) {
          try {
            await storage.remove([path]);
          } catch (cleanupError) {
            _log.warning('Could not remove an orphaned upload', fields: {'error': '$cleanupError'});
          }
          rethrow;
        }
      });

  Future<Uint8List> download(DocumentFile document) =>
      guard('documents.download', () => _client.storage.from(_bucket).download(document.storagePath));

  Future<void> update(String documentId, {required String name, required String category, String? notes}) =>
      guard('documents.update', () async {
        final rows = await _client
            .from('documents')
            .update({'name': name.trim(), 'category': category, 'notes': notes})
            .eq('id', documentId)
            .select('id');
        requireAffected(rows);
      });

  /// Removes the stored file first, then its record, so a record never
  /// outlives its file silently. Removing an already-missing file succeeds.
  Future<void> delete(DocumentFile document) => guard('documents.delete', () async {
        await _client.storage.from(_bucket).remove([document.storagePath]);
        final rows = await _client.from('documents').delete().eq('id', document.id).select('id');
        requireAffected(rows);
      });
}
