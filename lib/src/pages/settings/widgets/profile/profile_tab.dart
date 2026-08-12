import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/pages/settings/widgets/profile/view_model.dart';
import 'package:budgly/src/shared/widgets/buttons/button.dart';
import 'package:budgly/src/shared/widgets/buttons/constants.dart';
import 'package:budgly/src/core/exceptions/auth_exceptions.dart';
import 'package:budgly/src/shared/widgets/inputs/constants.dart';
import 'package:budgly/src/shared/widgets/snack_bar/snackbar.dart';
import 'package:budgly/src/shared/widgets/user/details.dart';
import 'package:budgly/src/shared/widgets/user/view_card.dart';
import 'package:budgly/src/shared/widgets/inputs/input.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBarMessage(
            message: AppLocalizations.of(context)!.nameChangedSuccessfully,
            type: SnackBarType.success,
          ),
        );
      }
    });
  }

  void _onChangePassword() {
    _viewModel
        .changePassword()
        .then((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBarMessage(
                message: AppLocalizations.of(
                  context,
                )!.passwordChangedSuccessfully,
                type: SnackBarType.success,
              ),
            );
          }
        })
        .onError((error, stackTrace) {
          if (!mounted) return;
          final exception = error as AuthenticationException;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBarMessage(
              message: exception.code == "password-change-failed"
                  ? AppLocalizations.of(context)!.passwordChangeFailed
                  : exception.message,
              type: SnackBarType.error,
            ),
          );
        });
  }

  void _displayChangePasswordDialog() {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                        child: BudglyButton(
                          text: tr.cancel,
                          type: ButtonType.error,
                          dense: true,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      Expanded(
                        child: BudglyButton(
                          text: tr.validate,
                          type: ButtonType.primary,
                          dense: true,
                          onPressed: () {
                            _onChangePassword();
                            Navigator.pop(context);
                          },
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

    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, child) {
        if (_viewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
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
              BudglyButton(
                text: tr.refreshProfile,
                type: ButtonType.primary,
                leadingIcon: Icons.refresh,
                onPressed: _viewModel.refreshUser,
              ),
              if (!_viewModel.currentUser!.isGoogleUser)
                BudglyButton(
                  text: tr.changePassword,
                  type: ButtonType.tertiary,
                  leadingIcon: Icons.lock,
                  onPressed: _displayChangePasswordDialog,
                ),
              const Spacer(),
              BudglyButton(
                text: tr.logout,
                type: ButtonType.error,
                leadingIcon: Icons.logout,
                onPressed: _viewModel.signOut,
              ),
            ],
          ),
        );
      },
    );
  }
}
