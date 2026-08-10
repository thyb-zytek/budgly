import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/pages/settings/widgets/user/view_model.dart';
import 'package:budgly/src/shared/widgets/buttons/button.dart';
import 'package:budgly/src/shared/widgets/buttons/constants.dart';
import 'package:budgly/src/core/exceptions/auth_exceptions.dart';
import 'package:budgly/src/shared/widgets/snack_bar/snackbar.dart';
import 'package:budgly/src/shared/widgets/user/change_password.dart';
import 'package:budgly/src/shared/widgets/user/details.dart';
import 'package:budgly/src/shared/widgets/user/view_card.dart';
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
          if (!mounted) return;
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.4,
            minChildSize: 0.3,
            maxChildSize: 0.8,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(100),
                      blurRadius: 10,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle for dragging
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Title
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Text(
                        AppLocalizations.of(context)!.changePassword,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    // Form content
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: ChangePasswordForm(
                          formKey: widget.viewModel.formKey,
                          oldPasswordController: widget.viewModel.oldPasswordController,
                          passwordController: widget.viewModel.passwordController,
                          confirmPasswordController:
                              widget.viewModel.confirmPasswordController,
                          validatePassword: widget.viewModel.validatePassword,
                          onSubmit: _onChangePassword,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
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
