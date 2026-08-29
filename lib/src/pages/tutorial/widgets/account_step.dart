import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/errors/app_user_message.dart';
import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/core/theme/snackbar.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/pages/tutorial/view_model.dart';
import 'package:budgly/src/pages/tutorial/widgets/tutorial_step_scaffold.dart';
import 'package:budgly/src/shared/domain/widgets/accounts/account_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AccountStep extends StatefulWidget {
  final TutorialViewModel viewModel;
  final VoidCallback onNext;

  const AccountStep({super.key, required this.viewModel, required this.onNext});

  @override
  State<AccountStep> createState() => _AccountStepState();
}

class _AccountStepState extends State<AccountStep> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final vm = widget.viewModel;
    if (vm.createdAccount?.id != null) {
      if (vm.accountNameController.text.isEmpty) {
        vm.accountNameController.text = vm.createdAccount!.name;
      }
      vm.setAccountColor(vm.createdAccount!.color ?? Colors.primaries[0]);
      if (vm.createdAccount!.picture != null) {
        vm.setAccountPicture(vm.createdAccount!.pictureUrl ?? vm.createdAccount!.picture);
      }
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final tr = AppLocalizations.of(context)!;
    final vm = widget.viewModel;

    setState(() => _isSubmitting = true);
    final isUpdate = vm.createdAccount?.id != null;

    try {
      if (isUpdate) {
        await vm.updateAccount(vm.createdAccount!);
      } else {
        await vm.createAccount(vm.createdAccount ??
            Account(name: vm.accountNameController.text.trim(), color: vm.accountColor));
      }

      if (!mounted) return;
      if (vm.createdAccount == null) {
        setState(() => _isSubmitting = false);
        return;
      }

      setState(() => _isSubmitting = false);

      HapticFeedback.mediumImpact();
      showAppSnackBar(
        context,
        message: isUpdate
            ? tr.accountUpdatedSuccessfully
            : tr.accountCreatedSuccessfully,
        type: SnackBarType.success,
      );
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) widget.onNext();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save account in tutorial', e, stackTrace);
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showAppSnackBar(
        context,
        message: AppUserMessage.error(classifyError(e)).resolve(context),
        type: SnackBarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final vm = widget.viewModel;
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        return TutorialStepScaffold(
          title: tr.tutorialStepAccounts,
          subtitle: tr.tutorialStepAccountsDescription,
          content: AbsorbPointer(
            absorbing: _isSubmitting,
            child: Column(
              spacing: BudglySpacing.md,
              children: [
                AccountForm(
                  formKey: _formKey,
                  viewModel: vm,
                  account: vm.createdAccount,
                  compact: true,
                  withPulse: vm.createdAccount?.id == null,
                  withHint: vm.createdAccount?.id == null,
                  enabled: !_isSubmitting,
                ),
                Text(
                  tr.tapToCustomize,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          primaryAction: ListenableBuilder(
            listenable: vm.accountNameController,
            builder: (context, _) {
              final enabled = vm.isAccountValid && !_isSubmitting;

              return SizedBox(
                width: double.infinity,
                child: FilledButton(
                                    onPressed: enabled ? _submit : null,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _isSubmitting
                        ? SizedBox(
                            key: const ValueKey('loading'),
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : Text(
                            tr.tutorialNext,
                            key: const ValueKey('label'),

                          ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
