import 'package:budgly/src/services/offline/local_cache.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The single process-wide [LocalCache].
///
/// Every service must share this instance: its lock serializes the
/// read-modify-write cycles of mutations and background revalidation. Creating
/// a second `LocalCache()` would silently bypass that protection.
final localCacheProvider = Provider<LocalCache>((ref) => LocalCache());
