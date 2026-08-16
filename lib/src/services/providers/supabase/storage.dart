import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'client.dart';

class StorageSupabase {
  sb.SupabaseClient get _client => supabase;

  Future<String?> uploadFile({
    required String bucketId,
    required String filePath,
    required String userId,
    String? prefix,
    String? fileName,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File at $filePath does not exist');
    }

    final fileExtension = file.path.split('.').last;
    final name =
        fileName != null && fileName.contains('.')
            ? fileName
            : '${fileName ?? 'avatar'}.$fileExtension';

    final objectName = '$userId/${prefix != null ? '$prefix/' : ''}$name';

    await _client.storage.from(bucketId).upload(objectName, file);
    return name;
  }

  Future<String> getSignedUrl({
    required String bucketId,
    required String filePath,
    int validityInSeconds = 3600,
  }) async {
    return _client.storage
        .from(bucketId)
        .createSignedUrl(filePath, validityInSeconds);
  }

  Future<Uint8List> getFileContent({
    required String bucketId,
    required String filePath,
  }) async {
    return _client.storage.from(bucketId).download(filePath);
  }

  Future<bool> deleteFile({
    required String bucketId,
    required String filePath,
  }) async {
    await _client.storage.from(bucketId).remove([filePath]);
    return true;
  }
}
