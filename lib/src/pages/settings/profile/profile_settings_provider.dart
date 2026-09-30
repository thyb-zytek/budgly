import 'package:budgly/src/core/auth/auth_exception.dart';
import 'package:budgly/src/core/errors/app_user_message.dart';
import 'package:budgly/src/state/action_status.dart';
import 'package:budgly/src/state/accounts_provider.dart';
import 'package:budgly/src/state/categories_provider.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:budgly/src/services/analytics/analytics_service_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_settings_provider.g.dart';

/// Pure validation logic for the change-password form, extracted so it has
/// no dependency on a `TextEditingController` or any ViewModel state.
///
/// [value] is the field currently being validated; [currentPassword] is the
/// live value of the "new password" field (irrelevant when [value] *is* the
/// new-password field itself — comparing it against itself always passes,
/// which is what the previous implementation did too).
String? validatePassword(String? value, String currentPassword) {
  if (value == null || value.isEmpty) return 'passwordRequired';
  if (currentPassword.isNotEmpty && value != currentPassword) {
    return 'passwordsDoNotMatch';
  }
  if (value.length < 6) return 'passwordTooShort';
  return null;
}

/// Page-scoped action state for profile settings. The shared profile data
/// remains owned by `ProfileSession`.
///
/// Named `ProfileSettings` rather than `Profile` to avoid colliding with the
/// already-heavily-overloaded `ProfileService/`ProfileSession`
/// naming (see `docs/ARCHITECTURE.md`).
///
/// Deliberately holds no `currentUser` field: that data is already reactive
/// via `profileSessionProvider` — a page watches both providers
/// side by side instead of one duplicating the other's data. This Notifier
/// only tracks the status of *actions* (loading/error/message), and no
/// longer owns the change-password `TextEditingController`s — those move to
/// the widget that owns the form (`ChangePasswordSheet`), which is the more
/// idiomatic split for Riverpod (Notifiers hold business state, not Flutter
/// framework objects).
@riverpod
class ProfileSettings extends _$ProfileSettings {
  @override
  ActionStatus build() => const ActionStatus.idle();

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    state = state.loading();
    try {
      await ref
          .read(profileSessionProvider.notifier)
          .changePassword(oldPassword, newPassword);
      if (!ref.mounted) return;
      state = state.success(
        const AppUserMessage.success(AppMessageKey.passwordChanged),
      );
    } catch (e) {
      if (!ref.mounted) return;
      final userMessage =
          e is AuthenticationException && e.code == 'password-change-failed'
          ? const AppUserMessage.error(AppMessageKey.passwordChangeFailed)
          : null; // let failure() classify anything else generically
      state = state.failure(e, message: userMessage);
    }
  }

  Future<void> loadUser() async {
    state = state.loading();
    try {
      await ref.read(profileSessionProvider.notifier).load(forceRefresh: true);
      if (!ref.mounted) return;
      state = state.doneLoading();
    } catch (e) {
      if (!ref.mounted) return;
      state = state.failure(e);
    }
  }

  Future<void> refreshUser() async {
    state = state.loading();
    try {
      // Replay every pending local mutation. Offline-first: we only replace
      // the local data with fresh server data once we are sure all pending
      // mutations reached the server (i.e. we are online). Otherwise we bail
      // out and keep the existing local data intact.
      final online = await ref
          .read(profileServiceProvider)
          .flushPendingMutations();
      if (!ref.mounted) return;
      if (!online) {
        throw StateError('offline: pending mutations could not be flushed');
      }

      // Online: safe to overwrite local caches/stores with server data.
      await Future.wait([
        ref.read(accountsSessionProvider.notifier).load(forceRefresh: true),
        ref.read(profileSessionProvider.notifier).refresh(),
      ]);
      if (!ref.mounted) return;

      final firstAccount = ref.read(accountsSessionProvider).accounts.isNotEmpty
          ? ref.read(accountsSessionProvider).accounts.first.id
          : null;
      if (firstAccount != null) {
        await ref
            .read(categoriesSessionProvider.notifier)
            .load(firstAccount, forceRefresh: true);
        if (!ref.mounted) return;
      }

      ref.read(analyticsServiceProvider).track('profile_refresh', const {
        'status': 'success',
      });
      state = state.success(
        const AppUserMessage.success(AppMessageKey.profileRefreshed),
      );
    } catch (e) {
      if (!ref.mounted) return;
      ref.read(analyticsServiceProvider).track('profile_refresh', const {
        'status': 'failed',
      });
      state = state.failure(
        e,
        message: const AppUserMessage.error(AppMessageKey.refreshProfileFailed),
      );
    }
  }

  Future<void> onChangeName(String name) async {
    try {
      await ref.read(profileSessionProvider.notifier).updateName(name);
      if (!ref.mounted) return;
      state = state.success(
        const AppUserMessage.success(AppMessageKey.nameChanged),
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = state.failure(e);
    }
  }

  Future<void> signOut() async {
    state = state.loading();
    try {
      await ref.read(profileSessionProvider.notifier).signOut();
      if (!ref.mounted) return;
      state = state.doneLoading();
    } catch (e) {
      if (!ref.mounted) return;
      state = state.failure(e);
    }
  }

  void consumeMessage() {
    state = state.consumeMessage();
  }
}
