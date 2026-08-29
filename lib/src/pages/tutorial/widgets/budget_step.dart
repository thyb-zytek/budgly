import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/extensions/amount.dart';
import 'package:budgly/src/core/extensions/currency.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/core/theme/input_styles.dart';
import 'package:budgly/src/pages/tutorial/view_model.dart';
import 'package:budgly/src/pages/tutorial/widgets/creation_recap.dart';
import 'package:budgly/src/pages/tutorial/widgets/tutorial_step_badge.dart';
import 'package:budgly/src/pages/tutorial/widgets/tutorial_step_scaffold.dart';
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
          CreationRecap(viewModel: viewModel),
          TextInput(
            controller: viewModel.revenueController,
            labelText: tr.revenue,
            type: InputType.currency,
            suffix: Padding(
              padding: const EdgeInsets.only(right: BudglySpacing.sm),
              child: Icon(
                viewModel.currencyCode.currencyIcon,
                size: 20,
                opticalSize: 14,
                color: theme.colorScheme.onSurface.withAlpha(155),
              ),
            ),
            textInputAction: TextInputAction.done,
            hotValidating: (v) {
              final amount = parseAmount(v ?? '');
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
          onPressed: () async {
            await viewModel.saveRevenue();
            onFinish();
          },
          child: Text(
            tr.tutorialFinish,
          ),
        ),
      ),
    );
  }
}
