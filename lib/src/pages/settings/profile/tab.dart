import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/pages/settings/profile/view_model.dart';
import 'package:budgly/src/pages/settings/profile/widgets/change_password_sheet.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:budgly/src/core/theme/snackbar.dart';
import 'package:budgly/src/core/auth/auth_exception.dart';
import 'package:budgly/src/shared/domain/widgets/user/details.dart';
import 'package:budgly/src/shared/domain/widgets/user/view_card.dart';
import 'package:budgly/src/shared/ui/widgets/layout/loading_indicator.dart';
import 'package:flutter/material.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late final ProfileViewModel _viewModel = ProfileViewModel();

  void _onChangeName(String name) {
    _viewModel.onChangeName(name).then((_) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: AppLocalizations.of(context)!.nameChangedSuccessfully,
          type: SnackBarType.success,
        );
      }
    });
  }

  void _onChangePassword() {
    _viewModel
        .changePassword(true)
        .then((_) {
          if (mounted) {
            showAppSnackBar(
              context,
              message: AppLocalizations.of(
                context,
              )!.passwordChangedSuccessfully,
              type: SnackBarType.success,
            );
          }
        })
        .onError((error, stackTrace) {
          if (!mounted) return;
          final message = error is AuthenticationException
              ? (error.code == "password-change-failed"
                  ? AppLocalizations.of(context)!.passwordChangeFailed
                  : error.message)
              : error.toString();
          showAppSnackBar(
            context,
            message: message,
            type: SnackBarType.error,
          );
        });
  }

  void _displayChangePasswordDialog() {
    ChangePasswordSheet.show(
      context,
      viewModel: _viewModel,
      onSubmit: _onChangePassword,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, child) {
        if (_viewModel.isLoading || _viewModel.currentUser == null) {
          return const AppLoadingIndicator();
        }

        final user = _viewModel.currentUser!;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.max,
            spacing: 16,
            children: [
              UserCard(user: user),
              UserDetails(
                user: user,
                onChangeName: _onChangeName,
              ),
              FilledButton.icon(
                style: ButtonType.primary.filledStyle(theme),
                onPressed: _viewModel.refreshUser,
                iconAlignment: IconAlignment.start,
                icon: Icon(
                  Icons.refresh,
                  color: ButtonType.primary.colors(theme).foreground,
                ),
                label: Text(
                  tr.refreshProfile,
                  style: ButtonType.primary.labelStyle(theme),
                ),
              ),
              if (!user.isGoogleUser)
                FilledButton.icon(
                  style: ButtonType.tertiary.filledStyle(theme),
                  onPressed: _displayChangePasswordDialog,
                  iconAlignment: IconAlignment.start,
                  icon: Icon(
                    Icons.lock,
                    color: ButtonType.tertiary.colors(theme).foreground,
                  ),
                  label: Text(
                    tr.changePassword,
                    style: ButtonType.tertiary.labelStyle(theme),
                  ),
                ),
              const Spacer(),
              FilledButton.icon(
                style: ButtonType.error.filledStyle(theme),
                onPressed: _viewModel.signOut,
                iconAlignment: IconAlignment.start,
                icon: Icon(
                  Icons.logout,
                  color: ButtonType.error.colors(theme).foreground,
                ),
                label: Text(
                  tr.logout,
                  style: ButtonType.error.labelStyle(theme),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
