import 'dart:async';
import 'dart:convert';

import 'package:budgly/src/core/logging/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PendingSync {
  const PendingSync({
    required this.id,
    required this.type,
    required this.operation,
    required this.payload,
    this.attempts = 0,
    this.nextAttemptAt,
    this.ownerUserId,
    this.permanent = false,
    this.lastError,
    this.revision = 0,
  });

  final String id;
  final String type;
  final String operation;
  final Map<String, dynamic> payload;
  final int attempts;
  final DateTime? nextAttemptAt;
  final String? ownerUserId;

  /// Set when the last failure was classified as permanent (the server
  /// rejected the mutation itself, e.g. a constraint or policy violation).
  /// A permanent operation is never dropped, but it is not replayed by the
  /// background triggers: only an explicit user retry or a new local edit of
  /// the same entity gives it another chance.
  final bool permanent;

  /// Short description of the last failure, for diagnostics only.
  final String? lastError;

  /// Incremented each time a newer mutation is coalesced into the operation
  /// that already holds this [id]. A replay pass remembers the revision it
  /// read: its outcome (success, failure) only applies if the queued operation
  /// still has that revision, so an edit made while the operation was being
  /// replayed is never discarded with it.
  final int revision;

  String get entityId => (payload['id'] ?? '').toString();

  bool get isReady =>
      !permanent &&
      (nextAttemptAt == null || !DateTime.now().isBefore(nextAttemptAt!));

  PendingSync copyWith({
    int? attempts,
    DateTime? nextAttemptAt,
    String? ownerUserId,
    bool? permanent,
    String? lastError,
    int? revision,
    bool clearNextAttemptAt = false,
  }) => PendingSync(
    id: id,
    type: type,
    operation: operation,
    payload: payload,
    attempts: attempts ?? this.attempts,
    nextAttemptAt: clearNextAttemptAt
        ? null
        : nextAttemptAt ?? this.nextAttemptAt,
    ownerUserId: ownerUserId ?? this.ownerUserId,
    permanent: permanent ?? this.permanent,
    lastError: lastError ?? this.lastError,
    revision: revision ?? this.revision,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'operation': operation,
    'payload': payload,
    'attempts': attempts,
    'next_attempt_at': nextAttemptAt?.toIso8601String(),
    'owner_user_id': ownerUserId,
    if (permanent) 'permanent': true,
    if (lastError != null) 'last_error': lastError,
    if (revision > 0) 'revision': revision,
  };

  factory PendingSync.fromJson(Map<String, dynamic> json) => PendingSync(
    id: json['id'] as String,
    type: json['type'] as String,
    operation: json['operation'] as String,
    payload: Map<String, dynamic>.from(json['payload'] as Map),
    attempts: (json['attempts'] as num?)?.toInt() ?? 0,
    nextAttemptAt: json['next_attempt_at'] != null
        ? DateTime.tryParse(json['next_attempt_at'].toString())
        : null,
    ownerUserId: json['owner_user_id']?.toString(),
    permanent: json['permanent'] == true,
    lastError: json['last_error']?.toString(),
    revision: (json['revision'] as num?)?.toInt() ?? 0,
  );
}

/// Persistent queue for Supabase mutations.
///
/// Supabase does not provide the same offline mutation queue as Firestore.
/// Operations are therefore persisted locally and replayed by SyncManager.
/// Mutations for the same entity are coalesced so the queue remains small and
/// replayable.
class SyncQueue {
  static const _key = 'offline.pending_sync.v2';
  static const _corruptKeyPrefix = 'offline.pending_sync.v2.corrupt.';
  static const _maxQuarantinedBlobs = 3;

  SyncQueue({this._ownerUserIdProvider});

  final String? Function()? _ownerUserIdProvider;

  // SharedPreferences writes are whole-value replacements. Serializing queue
  // mutations prevents two fast user actions from reading the same old queue
  // and accidentally dropping one of the operations.
  Future<void> _lock = Future.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final previous = _lock;
    final release = Completer<void>();
    _lock = previous.then((_) => release.future);
    return previous
        .then((_) => action())
        .whenComplete(() => release.complete());
  }

  Future<List<PendingSync>> _readRaw() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return <PendingSync>[];

    final List<dynamic> decoded;
    try {
      decoded = jsonDecode(raw) as List;
    } catch (e, st) {
      // The whole blob is unreadable. Never let the next write silently
      // overwrite it: keep the raw value so it can still be recovered.
      AppLogger.error('Failed to decode sync queue', e, st);
      await _quarantine(prefs, raw);
      await prefs.remove(_key);
      return <PendingSync>[];
    }

    final operations = <PendingSync>[];
    final rejected = <dynamic>[];
    for (final item in decoded) {
      try {
        operations.add(
          PendingSync.fromJson(Map<String, dynamic>.from(item as Map)),
        );
      } catch (e, st) {
        // One bad entry must not take the rest of the queue down with it.
        AppLogger.error('Skipping unreadable sync queue entry', e, st);
        rejected.add(item);
      }
    }
    if (rejected.isNotEmpty) {
      await _quarantine(prefs, jsonEncode(rejected));
      await _write(operations);
    }
    return operations;
  }

  Future<void> _quarantine(SharedPreferences prefs, String raw) async {
    try {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      await prefs.setString('$_corruptKeyPrefix$stamp', raw);
      final keys =
          prefs
              .getKeys()
              .where((key) => key.startsWith(_corruptKeyPrefix))
              .toList()
            ..sort();
      for (final key in keys.take(
        (keys.length - _maxQuarantinedBlobs).clamp(0, keys.length),
      )) {
        await prefs.remove(key);
      }
    } catch (e, st) {
      AppLogger.error('Failed to quarantine sync queue data', e, st);
    }
  }

  Future<List<PendingSync>> _read() async {
    final operations = await _readRaw();
    final ownerProvider = _ownerUserIdProvider;
    if (ownerProvider == null) return operations;

    // Legacy entries predate owner_user_id. Per the migration policy, assign
    // them to the authenticated user when first read in an authenticated
    // session. If the app starts signed out, keep them ownerless; the first
    // authenticated read after login will claim and persist them. Never claim
    // entries while the owner is null/empty, and never change an existing
    // owner. _read is only invoked inside _serialized queue operations.
    final currentOwner = ownerProvider();
    if (currentOwner == null || currentOwner.trim().isEmpty) {
      return operations;
    }

    var migrated = false;
    final ownedOperations = operations.map((operation) {
      final owner = operation.ownerUserId;
      if (owner != null && owner.trim().isNotEmpty) return operation;
      migrated = true;
      return operation.copyWith(ownerUserId: currentOwner);
    }).toList();

    if (migrated) await _write(ownedOperations);
    return ownedOperations;
  }

  Future<void> _write(List<PendingSync> operations) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(operations.map((operation) => operation.toJson()).toList()),
    );
  }

  Future<List<PendingSync>> all({bool readyOnly = false}) async {
    final operations = await _serialized(_read);
    if (!readyOnly) return operations;
    return operations.where((operation) => operation.isReady).toList();
  }

  Future<List<PendingSync>> forType(
    String type, {
    bool readyOnly = false,
  }) async {
    final operations = await all(readyOnly: readyOnly);
    return operations.where((operation) => operation.type == type).toList();
  }

  /// Operations captured by [ownerUserId], regardless of the current session.
  Future<List<PendingSync>> allForOwner(String ownerUserId) async {
    final operations = await all();
    return operations
        .where((operation) => operation.ownerUserId == ownerUserId)
        .toList();
  }

  /// Operations with a provable owner matching the current session.
  /// Without an owner provider (unit tests/standalone tools), every operation
  /// is considered current. Ownerless legacy entries are deliberately excluded.
  Future<List<PendingSync>> allForCurrentOwner() async {
    final operations = await all();
    final provider = _ownerUserIdProvider;
    if (provider == null) return operations;
    final current = provider();
    return operations
        .where(
          (operation) => current != null && operation.ownerUserId == current,
        )
        .toList();
  }

  Future<void> enqueue({
    required String id,
    required String type,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    final ownerUserId = _ownerUserIdProvider?.call();
    if (_ownerUserIdProvider != null &&
        (ownerUserId == null || ownerUserId.isEmpty)) {
      throw StateError(
        'Cannot enqueue a sync mutation without an authenticated user',
      );
    }

    await _serialized(() async {
      final operations = await _read();
      final entityId = (payload['id'] ?? '').toString();

      final entityOperations = operations
          .where(
            (item) =>
                item.type == type &&
                item.ownerUserId == ownerUserId &&
                entityId.isNotEmpty &&
                item.entityId == entityId,
          )
          .toList();

      final previous = entityOperations.isEmpty ? null : entityOperations.last;

      // Any operation about the same entity (or reusing the same operation id)
      // that is superseded here may be in flight in a replay pass that read it
      // earlier: give the new operation a strictly greater revision so that
      // pass can neither remove nor fail it, see [applyBatch].
      int nextRevision(String operationId) {
        var highest = -1;
        for (final item in operations) {
          final sameOperation = item.id == operationId;
          final sameEntity = entityOperations.any((e) => identical(e, item));
          if ((sameOperation || sameEntity) && item.revision > highest) {
            highest = item.revision;
          }
        }
        return highest + 1;
      }

      final previousIsPatchable =
          previous?.operation == 'create' || previous?.operation == 'update';

      if (previous?.operation == 'create' && operation == 'update') {
        // Keep the create identity but merge the payloads: a later update
        // may carry only the fields it changed, and side-channel keys such as
        // a queued local picture must survive the coalescing.
        final revision = nextRevision(previous!.id);
        operations.removeWhere((item) => item.id == previous.id);
        operations.add(
          PendingSync(
            id: previous.id,
            type: type,
            operation: 'create',
            payload: {...previous.payload, ...payload},
            ownerUserId: ownerUserId,
            revision: revision,
          ),
        );
      } else if (previous?.operation == 'create' && operation == 'delete') {
        // A create may already have reached the server even if the queue
        // persisted before the process crashed. Never cancel it here: replay
        // create -> delete so the remote state converges to the user's
        // latest intent instead of leaving an orphaned row behind.
        final revision = nextRevision(id);
        operations.removeWhere(
          (item) =>
              item.type == type &&
              item.ownerUserId == ownerUserId &&
              item.entityId == entityId &&
              item.operation == 'delete',
        );
        operations.add(
          PendingSync(
            id: id,
            type: type,
            operation: operation,
            payload: Map<String, dynamic>.from(payload),
            ownerUserId: ownerUserId,
            revision: revision,
          ),
        );
      } else {
        // update -> update is merged (partial patches must not overwrite each
        // other); every other combination keeps only the latest intent.
        final mergedPayload = previousIsPatchable && operation == 'update'
            ? {...previous!.payload, ...payload}
            : Map<String, dynamic>.from(payload);
        final revision = nextRevision(id);
        if (entityId.isNotEmpty) {
          operations.removeWhere(
            (item) =>
                item.type == type &&
                item.ownerUserId == ownerUserId &&
                item.entityId == entityId,
          );
        }
        operations.add(
          PendingSync(
            id: id,
            type: type,
            operation: operation,
            payload: mergedPayload,
            ownerUserId: ownerUserId,
            revision: revision,
          ),
        );
      }

      await _write(operations);
    });
  }

  static Duration backoffFor(int attempts) {
    final exponent = attempts.clamp(1, 8).toInt();
    final delaySeconds = (1 << exponent).clamp(2, 300).toInt();
    return Duration(seconds: delaySeconds);
  }

  Future<void> markFailed(String id) async {
    await applyBatch(failedIds: [id]);
  }

  Future<void> remove(String id) async {
    await removeMany({id});
  }

  /// Applies multiple successful/failed outcomes with a single persistence
  /// write. SharedPreferences replaces the complete string value, so flushing
  /// a batch one operation at a time turns an O(n) replay into n full JSON
  /// rewrites.
  ///
  /// [permanentFailures] maps an operation id to a short error description for
  /// failures the server will keep rejecting: they are flagged instead of
  /// being scheduled for another backoff attempt.
  ///
  /// [replayedRevisions] maps an operation id to the [PendingSync.revision] the
  /// replay pass read. When the queued operation has moved on since (a newer
  /// edit was coalesced into it while it was being replayed), the outcome
  /// belongs to the superseded content and is ignored: the operation stays
  /// queued, untouched, and is replayed again with its latest payload. An id
  /// absent from the map applies to whatever revision is queued.
  Future<void> applyBatch({
    Iterable<String> removeIds = const <String>[],
    Iterable<String> failedIds = const <String>[],
    Map<String, String> permanentFailures = const <String, String>{},
    Map<String, int> replayedRevisions = const <String, int>{},
  }) async {
    final idsToRemove = removeIds.toSet();
    final permanent = Map<String, String>.from(permanentFailures)
      ..removeWhere((id, _) => idsToRemove.contains(id));
    final idsToFail = failedIds.toSet()
      ..removeAll(idsToRemove)
      ..removeAll(permanent.keys);
    if (idsToRemove.isEmpty && idsToFail.isEmpty && permanent.isEmpty) return;

    await _serialized(() async {
      final operations = await _read();
      var changed = false;

      bool isCurrent(PendingSync operation) {
        final replayed = replayedRevisions[operation.id];
        return replayed == null || replayed == operation.revision;
      }

      if (idsToRemove.isNotEmpty) {
        final before = operations.length;
        operations.removeWhere(
          (operation) =>
              idsToRemove.contains(operation.id) && isCurrent(operation),
        );
        changed = changed || operations.length != before;
      }

      for (var index = 0; index < operations.length; index++) {
        final operation = operations[index];
        if (!isCurrent(operation)) continue;
        final permanentError = permanent[operation.id];
        if (permanentError != null) {
          operations[index] = operation.copyWith(
            attempts: operation.attempts + 1,
            permanent: true,
            lastError: permanentError,
            clearNextAttemptAt: true,
          );
          changed = true;
        } else if (idsToFail.contains(operation.id)) {
          final attempts = operation.attempts + 1;
          operations[index] = operation.copyWith(
            attempts: attempts,
            nextAttemptAt: DateTime.now().add(backoffFor(attempts)),
          );
          changed = true;
        }
      }

      if (changed) await _write(operations);
    });
  }

  Future<void> removeMany(Iterable<String> ids) async {
    await applyBatch(removeIds: ids);
  }

  Future<void> removeWhere(bool Function(PendingSync operation) test) async {
    await _serialized(() async {
      final operations = await _read();
      final before = operations.length;
      operations.removeWhere(test);
      if (operations.length != before) await _write(operations);
    });
  }

  Future<bool> hasPending({
    required String type,
    String? entityId,
    bool currentOwnerOnly = false,
  }) async {
    final operations = await all();
    final owner = _ownerUserIdProvider?.call();
    return operations.any((operation) {
      if (operation.type != type) return false;
      if (entityId != null && operation.entityId != entityId) return false;
      if (!currentOwnerOnly || _ownerUserIdProvider == null) return true;
      if (owner == null || owner.isEmpty) return false;
      return operation.ownerUserId == owner;
    });
  }

  Future<void> clear() async => _serialized(() => _write(const []));
}
