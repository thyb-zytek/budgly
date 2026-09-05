import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/pages/settings/profile/view_model.dart';
import 'package:budgly/src/pages/settings/profile/widgets/change_password_sheet.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:budgly/src/shared/domain/widgets/user/details.dart';
import 'package:budgly/src/shared/domain/widgets/user/view_card.dart';
import 'package:budgly/src/shared/ui/widgets/layout/loading_indicator.dart';
import 'package:budgly/src/shared/ui/widgets/feedback/view_model_feedback.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:flutter/material.dart';

class ProfileTab extends StatefulWidget {
  final ProfileViewModel? injectedViewModel;

  const ProfileTab({super.key, this.injectedViewModel});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late final ProfileViewModel _viewModel;
  late final bool _ownsViewModel;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.injectedViewModel == null;
    _viewModel = widget.injectedViewModel ?? ProfileViewModel();
  }

  @override
  void dispose() {
    if (_ownsViewModel) _viewModel.dispose();
    super.dispose();
  }

  void _displayChangePasswordDialog() {
    ChangePasswordSheet.show(
      context,
      viewModel: _viewModel,
      onSubmit: () => _viewModel.changePassword(true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return ViewModelFeedback(
      viewModel: _viewModel,
      child: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, child) {
          if (_viewModel.isLoading || _viewModel.currentUser == null) {
            return const AppLoadingIndicator();
          }

          final user = _viewModel.currentUser!;

          return Padding(
            padding: const EdgeInsets.all(BudglySpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          onChangeName: _viewModel.onChangeName,
                        ),
                        FilledButton.icon(
                          onPressed: _viewModel.refreshUser,
                          iconAlignment: IconAlignment.start,
                          icon: const Icon(Icons.refresh),
                          label: Text(tr.refreshProfile),
                        ),
                        if (!user.isGoogleUser)
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.tertiary,
                              foregroundColor: theme.colorScheme.onTertiary,
                            ),
                            onPressed: _displayChangePasswordDialog,
                            iconAlignment: IconAlignment.start,
                            icon: Icon(
                              Icons.lock,
                              color: theme.colorScheme.onTertiary,
                            ),
                            label: Text(
                              tr.changePassword,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.onTertiary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: BudglySpacing.lg),
                FilledButton.icon(
                  style: ButtonType.error.filledStyle(theme),
                  onPressed: _viewModel.signOut,
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
