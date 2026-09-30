import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/pages/settings/profile/profile_settings_provider.dart';
import 'package:budgly/src/pages/settings/profile/widgets/change_password_sheet.dart';
import 'package:budgly/src/shared/domain/widgets/user/details.dart';
import 'package:budgly/src/shared/domain/widgets/user/view_card.dart';
import 'package:budgly/src/shared/ui/widgets/feedback/riverpod_feedback.dart';
import 'package:budgly/src/shared/ui/widgets/layout/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  void _displayChangePasswordDialog(BuildContext context, WidgetRef ref) {
    ChangePasswordSheet.show(
      context,
      onSubmit: (oldPassword, newPassword) => ref
          .read(profileSettingsProvider.notifier)
          .changePassword(oldPassword: oldPassword, newPassword: newPassword),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final notifier = ref.read(profileSettingsProvider.notifier);

    final user = ref.watch(profileSessionProvider.select((s) => s.currentUser));
    final isLoading = ref.watch(
      profileSettingsProvider.select((s) => s.isLoading),
    );

    return RiverpodFeedback(
      messageListenable: profileSettingsProvider.select(
        (s) => s.pendingMessage,
      ),
      onConsume: (ref) =>
          ref.read(profileSettingsProvider.notifier).consumeMessage(),
      child: Builder(
        builder: (context) {
          if (isLoading || user == null) {
            return const AppLoadingIndicator();
          }

          return Padding(
            padding: EdgeInsets.all(BudglySpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: BudglySpacing.lg,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      spacing: 16,
                      children: [
                        UserCard(user: user),
                        UserDetails(
                          user: user,
                          onChangeName: notifier.onChangeName,
                        ),
                        FilledButton.icon(
                          onPressed: notifier.refreshUser,
                          iconAlignment: IconAlignment.start,
                          icon: const Icon(Icons.refresh),
                          label: Text(tr.refreshProfile),
                        ),
                        if (!user.isGoogleUser)
                          FilledButton.icon(
                            style: ButtonType.tertiary.filledStyle(theme),
                            onPressed: () =>
                                _displayChangePasswordDialog(context, ref),
                            iconAlignment: IconAlignment.start,
                            icon: Icon(
                              Icons.lock,
                              color: ButtonType.tertiary
                                  .colors(theme)
                                  .foreground,
                            ),
                            label: Text(
                              tr.changePassword,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: ButtonType.tertiary
                                    .colors(theme)
                                    .foreground,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                FilledButton.icon(
                  style: ButtonType.error.filledStyle(theme),
                  onPressed: notifier.signOut,
                  iconAlignment: IconAlignment.start,
                  icon: Icon(
                    Icons.logout,
                    color: ButtonType.error.colors(theme).foreground,
                  ),
                  label: Text(tr.logout),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
