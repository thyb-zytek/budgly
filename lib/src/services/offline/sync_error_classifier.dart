import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

/// Decides whether a failed replay can ever succeed by simply trying again.
///
/// Returns `true` only for errors where the *server rejected the mutation
/// itself* (constraint or policy violation, invalid data) or where the local
/// payload cannot be decoded. Everything else — network failures, timeouts,
/// expired tokens, unknown errors — is treated as transient and retried with
/// backoff. When in doubt this function must answer `false`: a wrongly
/// "permanent" operation stops being replayed by background triggers.
///
/// Permanent operations are never dropped; they are surfaced to the user and
/// replayed on an explicit retry or when the entity is edited again.
bool isPermanentSyncError(Object error) {
  if (error is PostgrestException) {
    final code = error.code ?? '';
    // 22xxx data exception, 23xxx integrity constraint violation,
    // 42xxx syntax error or access rule violation (includes 42501, RLS).
    return code.startsWith('22') ||
        code.startsWith('23') ||
        code.startsWith('42');
  }
  if (error is FirebaseException) {
    const permanentCodes = {
      'permission-denied',
      'invalid-argument',
      'not-found',
      'already-exists',
      'out-of-range',
    };
    return permanentCodes.contains(error.code);
  }
  // A payload that cannot be decoded will never decode on the next attempt.
  return error is FormatException || error is TypeError;
}
