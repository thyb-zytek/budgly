import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/extensions/currency.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:budgly/src/core/theme/input_styles.dart';
import 'package:budgly/src/pages/tutorial/view_model.dart';
import 'package:budgly/src/pages/tutorial/widgets/tutorial_step_scaffold.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:budgly/src/shared/ui/widgets/layout/avatar.dart';
import 'package:budgly/src/shared/ui/widgets/inputs/input.dart';
import 'package:flutter/material.dart';

class BudgetStep extends StatelessWidget {
  final TutorialViewModel viewModel;
  final VoidCallback onFinish;

  const BudgetStep({
    super.key,
    required this.viewModel,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final currencyCode = ProfileService.instance.currency;

    return TutorialStepScaffold(
      badge: TutorialStepBadge(
        child: Icon(
          Icons.savings_rounded,
          size: 48,
          color: theme.colorScheme.primary,
        ),
      ),
      title: tr.tutorialStepBudget,
      subtitle: tr.tutorialStepBudgetDescription,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 24,
        children: [
          _CreationRecap(viewModel: viewModel),
          TextInput(
            controller: viewModel.revenueController,
            labelText: tr.revenue,
            type: InputType.currency,
            suffix: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                currencyCode.currencyIcon,
                size: 20,
                opticalSize: 14,
                color: theme.colorScheme.onSurface.withAlpha(155),
              ),
            ),
            textInputAction: TextInputAction.done,
            hotValidating: (v) {
              final amount = double.tryParse((v ?? '').replaceAll(',', '.'));
              if (v != null && v.isNotEmpty && (amount == null || amount <= 0)) {
                return tr.amountInvalid;
              }
              return null;
            },
          ),
        ],
      ),
      primaryAction: SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: ButtonType.primary.filledStyle(theme),
          onPressed: () async {
            await viewModel.saveRevenue();
            onFinish();
          },
          child: Text(
            tr.tutorialFinish,
            style: ButtonType.primary.labelStyle(theme),
          ),
        ),
      ),
      secondaryAction: TextButton(
        onPressed: onFinish,
        child: Text(
          tr.tutorialSkip,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _CreationRecap extends StatelessWidget {
  final TutorialViewModel viewModel;

  const _CreationRecap({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              spacing: 16,
              children: [
                Avatar(
                  initial: viewModel.accountInitial,
                  backgroundColor: viewModel.accountColor,
                  picture: viewModel.accountPicture,
                  isLocalPicture: viewModel.isLocalPicture,
                  size: 48,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        viewModel.accountNameController.text,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        tr.tutorialCategoryCount(
                          viewModel.createdCategories.length,
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        if (viewModel.createdCategories.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: viewModel.createdCategories.map((category) {
                final color = category.color ?? theme.colorScheme.primary;
                return Row(
                  spacing: 12,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color.withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: category.icon != null
                          ? Icon(category.icon!.toIconData(), size: 16, color: color)
                          : Icon(Icons.category_rounded, size: 16, color: color),
                    ),
                    Expanded(
                      child: Text(
                        category.name ?? '',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
