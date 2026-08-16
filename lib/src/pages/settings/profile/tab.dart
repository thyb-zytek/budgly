import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/pages/settings/profile/view_model.dart';
import 'package:budgly/src/core/theme/bottom_sheet.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:budgly/src/core/theme/snackbar.dart';
import 'package:budgly/src/core/auth/auth_exception.dart';
import 'package:budgly/src/core/theme/input_styles.dart';
import 'package:budgly/src/shared/widgets/user/details.dart';
import 'package:budgly/src/shared/widgets/user/view_card.dart';
import 'package:budgly/src/shared/widgets/inputs/input.dart';
import 'package:budgly/src/shared/widgets/loading/loading_indicator.dart';
import 'package:flutter/material.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  ProfileViewModel _viewModel = ProfileViewModel();
  @override
  void initState() {
    super.initState();
  }

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
        .changePassword()
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
          final exception = error as AuthenticationException;
          showAppSnackBar(
            context,
            message: exception.code == "password-change-failed"
                ? AppLocalizations.of(context)!.passwordChangeFailed
                : exception.message,
            type: SnackBarType.error,
          );
        });
  }

  void _displayChangePasswordDialog() {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    showAppBottomSheet(
      context,
      builder: (context) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 24,
              children: [
                Text(
                  tr.editPassword,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: AutofillGroup(
                    child: Form(
                      key: _viewModel.formKey,
                      child: Column(
                        spacing: 8,
                        children: [
                          TextInput(
                            controller: _viewModel.oldPasswordController,
                            labelText: tr.oldPassword,
                            type: InputType.password,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) =>
                                FocusScope.of(context).nextFocus(),
                            hotValidating: (v) {
                              if (v?.isEmpty ?? true) {
                                return tr.passwordRequired;
                              } else {
                                return null;
                              }
                            },
                          ),
                          TextInput(
                            controller: _viewModel.passwordController,
                            labelText: tr.password,
                            type: InputType.password,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) =>
                                FocusScope.of(context).nextFocus(),
                            hotValidating: (v) {
                              String? result = _viewModel.validatePassword(v);
                              if (result == "passwordRequired") {
                                return tr.passwordRequired;
                              } else if (result == "passwordTooShort") {
                                return tr.passwordTooShort;
                              } else {
                                return result;
                              }
                            },
                          ),
                          TextInput(
                            controller: _viewModel.confirmPasswordController,
                            labelText: tr.confirmPassword,
                            type: InputType.password,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) {
                              _onChangePassword();
                              Navigator.pop(context);
                            },
                            hotValidating: (v) {
                              String? result = _viewModel.validatePassword(v);
                              if (result == "passwordRequired") {
                                return tr.passwordRequired;
                              } else if (result == "passwordsDoNotMatch") {
                                return tr.passwordsDontMatch;
                              } else {
                                return result;
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    spacing: 16,
                    children: [
                      Expanded(
                        child: FilledButton(
                          style: ButtonType.error.filledStyle(theme, dense: true),
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            tr.cancel,
                            style: ButtonType.error.labelStyle(theme, dense: true),
                          ),
                        ),
                      ),
                      Expanded(
                        child: FilledButton(
                          style: ButtonType.primary.filledStyle(theme, dense: true),
                          onPressed: () {
                            _onChangePassword();
                            Navigator.pop(context);
                          },
                          child: Text(
                            tr.validate,
                            style: ButtonType.primary.labelStyle(theme, dense: true),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, child) {
        if (_viewModel.isLoading) {
          return const AppLoadingIndicator();
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.max,
            spacing: 16,
            children: [
              UserCard(user: _viewModel.currentUser!),
              UserDetails(
                user: _viewModel.currentUser!,
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
              if (!_viewModel.currentUser!.isGoogleUser)
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
