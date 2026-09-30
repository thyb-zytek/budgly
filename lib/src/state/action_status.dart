import 'package:budgly/src/core/errors/app_user_message.dart';

/// Shared status for action-oriented Riverpod Notifiers.
///
/// `AsyncValue<T>` (Riverpod's built-in loading/data/error type) was
/// considered and rejected as the state type for these pages: most migrated
/// ViewModels here are action-oriented (change a password, sign out, rename
/// a profile) rather than a single piece of fetched data — there is no
/// natural `T` to wrap. `AsyncValue` also has no concept of a one-shot
/// "show this message once" event, which `pendingUserMessage` is. Keeping a
/// small dedicated state class, reused across every migrated page, keeps
/// that concern explicit instead of overloading `AsyncValue` semantics.
///
/// A page whose state genuinely *is* one piece of async data (list of
/// accounts, a loaded document, etc.) should still reach for `AsyncValue`
/// (or `AsyncNotifier`) directly instead of this class — this is
/// specifically for the "loading / error / one-shot message" shape shared
/// by action-oriented pages.
class ActionStatus {
  const ActionStatus._({
    this.isLoading = false,
    this.error,
    this.pendingMessage,
  });

  const ActionStatus.idle() : this._();

  final bool isLoading;
  final Object? error;
  final AppUserMessage? pendingMessage;

  bool get hasError => error != null;

  /// Starts an action and clears any previous error or pending message.
  ActionStatus loading() => const ActionStatus._(isLoading: true);

  /// Stops loading while preserving an existing error/message.
  ActionStatus doneLoading() => ActionStatus._(
    isLoading: false,
    error: error,
    pendingMessage: pendingMessage,
  );

  /// Queues a one-shot success message.
  ActionStatus success(AppUserMessage message) =>
      ActionStatus._(pendingMessage: message);

  /// Records an error and queues a user-facing message when needed.
  ActionStatus failure(Object error, {AppUserMessage? message}) =>
      ActionStatus._(
        error: error,
        pendingMessage: message ?? AppUserMessage.error(classifyError(error)),
      );

  /// Clears the pending one-shot message while preserving other state.
  ActionStatus consumeMessage() =>
      ActionStatus._(isLoading: isLoading, error: error);

  @override
  bool operator ==(Object other) =>
      other is ActionStatus &&
      other.isLoading == isLoading &&
      other.error == error &&
      other.pendingMessage == pendingMessage;

  @override
  int get hashCode => Object.hash(isLoading, error, pendingMessage);
}
