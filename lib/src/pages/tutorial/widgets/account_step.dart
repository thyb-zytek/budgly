import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/errors/app_user_message.dart';
import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/core/theme/snackbar.dart';
import 'package:budgly/src/pages/tutorial/tutorial_provider.dart';
import 'package:budgly/src/pages/tutorial/widgets/tutorial_step_scaffold.dart';
import 'package:budgly/src/shared/domain/widgets/accounts/account_form.dart';
import 'package:budgly/src/shared/ui/widgets/image/account_image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AccountStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  const AccountStep({super.key, required this.onNext});

  @override
  ConsumerState<AccountStep> createState() => _AccountStepState();
}

class _AccountStepState extends ConsumerState<AccountStep> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  bool _isSubmitting = false;
  Color _color = Colors.primaries.first;
  String? _picture;

  @override
  void initState() {
    super.initState();
    final state = ref.read(tutorialProvider);
    _nameController = TextEditingController(
      text: state.createdAccount?.name ?? '',
    );
    _color = state.accountColor;
    _picture = state.accountPicture;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || _nameController.text.trim().isEmpty) return;
    final tr = AppLocalizations.of(context)!;
    final state = ref.read(tutorialProvider);
    final notifier = ref.read(tutorialProvider.notifier);
    setState(() => _isSubmitting = true);
    final isUpdate = state.createdAccount?.id != null;
    try {
      await notifier.saveAccount(
        name: _nameController.text,
        isUpdate: isUpdate,
      );
      if (!mounted) return;
      if (ref.read(tutorialProvider).createdAccount == null) return;
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
      showAppSnackBar(
        context,
        message: AppUserMessage.error(classifyError(e)).resolve(context),
        type: SnackBarType.error,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = ref.watch(tutorialProvider);
    final notifier = ref.read(tutorialProvider.notifier);
    if (_nameController.text.isEmpty &&
        state.createdAccount?.name.isNotEmpty == true) {
      _nameController.text = state.createdAccount!.name;
    }

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
              nameController: _nameController,
              initialColor: _color,
              initialPicture: _picture,
              pickImage: AccountImagePicker.pickAndCropImage,
              onColorChanged: (color) {
                _color = color;
                notifier.setAccountCustomization(
                  color: color,
                  picture: _picture,
                );
              },
              onPictureChanged: (picture) {
                _picture = picture;
                notifier.setAccountCustomization(
                  color: _color,
                  picture: picture,
                );
              },
              compact: true,
              withPulse: state.createdAccount?.id == null,
              withHint: state.createdAccount?.id == null,
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
      primaryAction: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _nameController,
        builder: (context, value, _) => SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: value.text.trim().isNotEmpty && !_isSubmitting
                ? _submit
                : null,
            child: _isSubmitting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onPrimary,
                    ),
                  )
                : Text(tr.tutorialNext),
          ),
        ),
      ),
    );
  }
}
