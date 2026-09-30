import 'package:budgly/src/services/offline/sync_error_classifier.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Direct unit coverage of `isPermanentSyncError` (docs/AUDIT_PLAN.md, S6),
/// previously exercised only indirectly through a hand-rolled classifier
/// closure in `sync_manager_flush_loop_test.dart`, never the real function.
///
/// The rule this function must never break: when in doubt, answer `false`
/// (transient) rather than `true` (permanent) — a wrongly "permanent"
/// operation silently stops being retried in the background.
void main() {
  group('Postgrest (Supabase) errors', () {
    const permanentCodes = ['22001', '23503', '23505', '42501', '42601'];
    for (final code in permanentCodes) {
      test('$code (integrity/data/access violation) is permanent', () {
        expect(
          isPermanentSyncError(PostgrestException(message: 'boom', code: code)),
          isTrue,
        );
      });
    }

    test('a connection-related code (08xxx) is transient', () {
      expect(
        isPermanentSyncError(
          const PostgrestException(
            message: 'connection failure',
            code: '08000',
          ),
        ),
        isFalse,
      );
    });

    test('a null code is transient, not permanent by default', () {
      expect(
        isPermanentSyncError(const PostgrestException(message: 'unknown')),
        isFalse,
      );
    });
  });

  group('Firebase (Firestore) errors', () {
    const permanentCodes = [
      'permission-denied',
      'invalid-argument',
      'not-found',
      'already-exists',
      'out-of-range',
    ];
    for (final code in permanentCodes) {
      test('$code is permanent', () {
        expect(
          isPermanentSyncError(
            FirebaseException(plugin: 'cloud_firestore', code: code),
          ),
          isTrue,
        );
      });
    }

    const transientCodes = [
      'unavailable',
      'deadline-exceeded',
      'aborted',
      'unauthenticated',
      'unknown',
    ];
    for (final code in transientCodes) {
      test('$code is transient, not permanent', () {
        expect(
          isPermanentSyncError(
            FirebaseException(plugin: 'cloud_firestore', code: code),
          ),
          isFalse,
        );
      });
    }
  });

  group('everything else', () {
    test('a payload that cannot be decoded (FormatException) is permanent', () {
      expect(isPermanentSyncError(const FormatException('bad json')), isTrue);
    });

    test('a TypeError (payload shape mismatch) is permanent', () {
      // Trigger a real TypeError rather than constructing one directly (its
      // constructor isn't part of the public API).
      Object error;
      try {
        const dynamic value = 'not a map';
        value as Map<String, dynamic>;
        error = StateError('unreachable');
      } catch (e) {
        error = e;
      }
      expect(error, isA<TypeError>());
      expect(isPermanentSyncError(error), isTrue);
    });

    test(
      'a network failure (StateError, TimeoutException, ...) is transient',
      () {
        expect(isPermanentSyncError(StateError('offline')), isFalse);
        expect(isPermanentSyncError(Exception('socket closed')), isFalse);
      },
    );
  });
}
