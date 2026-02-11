import 'package:app/l10n/app_localizations.dart';
import 'package:app/src/pages/settings/widgets/user/view_model.dart';
import 'package:app/src/shared/widgets/buttons/button.dart';
import 'package:app/src/shared/widgets/buttons/constants.dart';
import 'package:app/src/core/exceptions/auth_exceptions.dart';
import 'package:app/src/shared/widgets/snack_bar/snackbar.dart';
import 'package:app/src/shared/widgets/user/change_password.dart';
import 'package:app/src/shared/widgets/user/details.dart';
import 'package:app/src/shared/widgets/user/view_card.dart';
import 'package:flutter/material.dart';

class UserTab extends StatefulWidget {
  final UserViewModel viewModel;
  const UserTab({super.key, required this.viewModel});

  @override
  State<UserTab> createState() => _UserTabState();
}

class _UserTabState extends State<UserTab> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.refreshUser();
  }

  void _onChangeName(String name) {
    widget.viewModel.onChangeName(name).then((_) {
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
    widget.viewModel
        .changePassword()
        .then((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBarMessage(
                message:
                    AppLocalizations.of(context)!.passwordChangedSuccessfully,
                type: SnackBarType.success,
              ),
            );
          }
        })
        .onError((error, stackTrace) {
          final exception = error as AuthenticationException;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBarMessage(
              message:
                  exception.code == "password-change-failed"
                      ? AppLocalizations.of(context)!.passwordChangeFailed
                      : exception.message,
              type: SnackBarType.error,
            ),
          );
        });
  }

  void _displayChangePasswordDialog() {
    showDialog(
      context: context,
      builder:
          (context) => ChangePasswordForm(
            formKey: widget.viewModel.formKey,
            oldPasswordController: widget.viewModel.oldPasswordController,
            passwordController: widget.viewModel.passwordController,
            confirmPasswordController:
                widget.viewModel.confirmPasswordController,
            validatePassword: widget.viewModel.validatePassword,
            onSubmit: _onChangePassword,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;

    return AnimatedBuilder(
      animation: widget.viewModel,
      builder: (context, child) {
        if (widget.viewModel.isLoading) {
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
              UserCard(user: widget.viewModel.currentUser!),
              UserDetails(
                user: widget.viewModel.currentUser!,
                onChangeName: _onChangeName,
              ),
              BudglyButton(
                text: tr.refreshProfile,
                type: ButtonType.primary,
                leadingIcon: Icons.refresh,
                onPressed: widget.viewModel.refreshUser,
              ),
              if (!widget.viewModel.currentUser!.isGoogleUser)
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
                onPressed: widget.viewModel.signOut,
              ),
            ],
          ),
        );
      },
    );
  }
}
