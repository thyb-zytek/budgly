import 'dart:async';

/// Small test-side guard for async operations that otherwise make a suite look
/// hung forever. Production code must not depend on this helper.
Future<T> guardedAsync<T>(
  Future<T> future, {
  Duration timeout = const Duration(seconds: 20),
  String? description,
}) {
  return future.timeout(
    timeout,
    onTimeout: () => throw TimeoutException(
      description ?? 'Test async operation did not complete',
      timeout,
    ),
  );
}
