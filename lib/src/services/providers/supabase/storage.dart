import 'dart:io';

import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/core/validation/upload_validation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'client.dart';
import 'signed_url_cache.dart';

class StorageSupabase {
  final sb.SupabaseClient? _injected;
  late final sb.SupabaseClient _client = _injected ?? supabase;
  final SignedUrlCache _signedUrlCache;
  final Map<String, Future<String>> _inFlightSignedUrls = {};

  StorageSupabase({sb.SupabaseClient? client, DateTime Function()? now})
    : _injected = client,
      _signedUrlCache = SignedUrlCache(now: now);

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
    final name = fileName != null && fileName.contains('.')
        ? fileName
        : '${fileName ?? 'avatar'}.$fileExtension';

    validateUploadConstraints(
      sizeBytes: await file.length(),
      fileExtension: fileExtension,
    );

    final objectName = '$userId/${prefix != null ? '$prefix/' : ''}$name';

    await _client.storage.from(bucketId).upload(objectName, file);
    _invalidateSignedUrl(bucketId: bucketId, filePath: objectName);
    return name;
  }

  Future<String> getSignedUrl({
    required String bucketId,
    required String filePath,
    int validityInSeconds = 3600,
  }) async {
    final key = _signedUrlKey(bucketId, filePath);
    final cached = _signedUrlCache.get(
      key,
      validityInSeconds: validityInSeconds,
    );
    if (cached != null) return cached;

    final inFlight = _inFlightSignedUrls[key];
    if (inFlight != null) return inFlight;

    final future = _createAndCacheSignedUrl(
      bucketId: bucketId,
      filePath: filePath,
      validityInSeconds: validityInSeconds,
      key: key,
    );
    _inFlightSignedUrls[key] = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlightSignedUrls[key], future)) {
        _inFlightSignedUrls.remove(key);
      }
    }
  }

  Future<String> _createAndCacheSignedUrl({
    required String bucketId,
    required String filePath,
    required int validityInSeconds,
    required String key,
  }) async {
    final url = await _client.storage
        .from(bucketId)
        .createSignedUrl(filePath, validityInSeconds);
    _signedUrlCache.put(key, url: url, validityInSeconds: validityInSeconds);
    return url;
  }

  void clearSignedUrlCache() {
    _signedUrlCache.clear();
  }

  void _invalidateSignedUrl({
    required String bucketId,
    required String filePath,
  }) {
    _signedUrlCache.invalidate(_signedUrlKey(bucketId, filePath));
  }

  String _signedUrlKey(String bucketId, String filePath) =>
      '$bucketId:$filePath';

  Future<bool> deleteFile({
    required String bucketId,
    required String filePath,
  }) async {
    await _client.storage.from(bucketId).remove([filePath]);
    _invalidateSignedUrl(bucketId: bucketId, filePath: filePath);
    return true;
  }

  /// Deletes every object under [folderPath]. Failures are logged and
  /// swallowed unless [throwOnFailure] is set (durable cleanup needs to know so
  /// it can retry).
  Future<void> deleteFolder({
    required String bucketId,
    required String folderPath,
    bool throwOnFailure = false,
  }) async {
    try {
      final files = await _client.storage.from(bucketId).list(path: folderPath);
      if (files.isEmpty) return;
      final paths = files.map((f) => '$folderPath/${f.name}').toList();
      await _client.storage.from(bucketId).remove(paths);
      for (final path in paths) {
        _invalidateSignedUrl(bucketId: bucketId, filePath: path);
      }
    } catch (e, st) {
      AppLogger.error('Failed to delete storage folder', e, st);
      if (throwOnFailure) rethrow;
    }
  }
}
