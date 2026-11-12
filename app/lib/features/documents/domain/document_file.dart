import '../../../core/utils/json.dart';

/// Categories a document can be filed under (enforced by the database).
const List<String> documentCategories = [
  'general',
  'contract',
  'invoice',
  'receipt',
  'quotation',
  'identity',
  'report',
  'other',
];

/// Largest file the storage bucket accepts.
const int maxDocumentBytes = 20 * 1024 * 1024;

/// File extensions the bucket accepts, with the content type stored for each.
const Map<String, String> documentMimeTypes = {
  'pdf': 'application/pdf',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'webp': 'image/webp',
  'txt': 'text/plain',
  'csv': 'text/csv',
  'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
};

/// Content type for a file name, or null when the type is not accepted.
String? mimeTypeForFileName(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return null;
  return documentMimeTypes[fileName.substring(dot + 1).toLowerCase()];
}

/// "1.4 MB", "320 KB".
String formatFileSize(int bytes) {
  if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  if (bytes >= 1024) return '${(bytes / 1024).round()} KB';
  return '$bytes B';
}

class DocumentFile {
  const DocumentFile({
    required this.id,
    required this.name,
    required this.category,
    required this.storagePath,
    required this.mimeType,
    required this.sizeBytes,
    this.customerId,
    this.customerName,
    this.notes,
    this.createdAt,
  });

  factory DocumentFile.fromJson(JsonMap json) => DocumentFile(
        id: asString(json['id']),
        name: asString(json['name']),
        category: asString(json['category'], 'general'),
        storagePath: asString(json['storage_path']),
        mimeType: asString(json['mime_type']),
        sizeBytes: asInt(json['size_bytes']),
        customerId: asStringOrNull(json['customer_id']),
        customerName: asStringOrNull(asJsonMap(json['customer'])['name']),
        notes: asStringOrNull(json['notes']),
        createdAt: asDateTime(json['created_at']),
      );

  final String id;
  final String name;
  final String category;
  final String storagePath;
  final String mimeType;
  final int sizeBytes;
  final String? customerId;
  final String? customerName;
  final String? notes;
  final DateTime? createdAt;

  bool get isImage => mimeType.startsWith('image/');
  bool get isPdf => mimeType == 'application/pdf';

  /// Name of the stored file (last path segment), used when saving a copy.
  String get fileName => storagePath.split('/').last;
}
