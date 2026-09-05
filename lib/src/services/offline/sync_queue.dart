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
  });

  final String id;
  final String type;
  final String operation;
  final Map<String, dynamic> payload;
  final int attempts;
  final DateTime? nextAttemptAt;

  String get entityId => (payload['id'] ?? '').toString();

  bool get isReady =>
      nextAttemptAt == null || !DateTime.now().isBefore(nextAttemptAt!);

  PendingSync copyWith({
    int? attempts,
    DateTime? nextAttemptAt,
  }) => PendingSync(
        id: id,
        type: type,
        operation: operation,
        payload: payload,
        attempts: attempts ?? this.attempts,
        nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'operation': operation,
        'payload': payload,
        'attempts': attempts,
        'next_attempt_at': nextAttemptAt?.toIso8601String(),
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

  static final SyncQueue instance = SyncQueue._();

  SyncQueue._();

  // SharedPreferences writes are whole-value replacements. Serializing queue
  // mutations prevents two fast user actions from reading the same old queue
  // and accidentally dropping one of the operations.
  Future<void> _lock = Future.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final previous = _lock;
    final release = Completer<void>();
    _lock = previous.then((_) => release.future);
    return previous.then((_) => action()).whenComplete(() => release.complete());
  }

  Future<List<PendingSync>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return <PendingSync>[];

    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((item) => PendingSync.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList();
    } catch (e, st) {
      AppLogger.error('Failed to decode sync queue', e, st);
      return <PendingSync>[];
    }
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

  Future<void> enqueue({
    required String id,
    required String type,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    await _serialized(() async {
      final operations = await _read();
      final entityId = (payload['id'] ?? '').toString();
      final entityOperations = operations
          .where((item) =>
              item.type == type &&
              entityId.isNotEmpty &&
              item.entityId == entityId)
          .toList();

      final previous = entityOperations.isEmpty ? null : entityOperations.last;

      if (previous?.operation == 'create' && operation == 'update') {
        operations.removeWhere((item) => item.id == previous!.id);
        operations.add(
          PendingSync(
            id: previous!.id,
            type: type,
            operation: 'create',
            payload: Map<String, dynamic>.from(payload),
          ),
        );
      } else if (previous?.operation == 'create' && operation == 'delete') {
        operations.removeWhere(
          (item) => item.type == type && item.entityId == entityId,
        );
      } else {
        if (entityId.isNotEmpty) {
          operations.removeWhere(
            (item) => item.type == type && item.entityId == entityId,
          );
        }
        operations.add(
          PendingSync(
            id: id,
            type: type,
            operation: operation,
            payload: Map<String, dynamic>.from(payload),
          ),
        );
      }

      await _write(operations);
    });
  }

  Future<void> markFailed(String id) async {
    await _serialized(() async {
      final operations = await _read();
      final index = operations.indexWhere((operation) => operation.id == id);
      if (index == -1) return;

      final operation = operations[index];
      final attempts = operation.attempts + 1;
      final exponent = attempts.clamp(1, 8).toInt();
      final delaySeconds = (1 << exponent).clamp(2, 300).toInt();
      operations[index] = operation.copyWith(
        attempts: attempts,
        nextAttemptAt: DateTime.now().add(Duration(seconds: delaySeconds)),
      );
      await _write(operations);
    });
  }

  Future<void> remove(String id) async {
    await _serialized(() async {
      final operations = await _read();
      operations.removeWhere((operation) => operation.id == id);
      await _write(operations);
    });
  }

  Future<void> removeWhere(bool Function(PendingSync operation) test) async {
    await _serialized(() async {
      final operations = await _read();
      operations.removeWhere(test);
      await _write(operations);
    });
  }

  Future<bool> hasPending({required String type, String? entityId}) async {
    final operations = await all();
    return operations.any((operation) {
      if (operation.type != type) return false;
      return entityId == null || operation.entityId == entityId;
    });
  }


  Future<void> clear() async => _serialized(() => _write(const []));
}
