import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/extensions/amount.dart';
import 'package:budgly/src/core/extensions/currency.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/core/theme/input_styles.dart';
import 'package:budgly/src/pages/tutorial/tutorial_provider.dart';
import 'package:budgly/src/pages/tutorial/widgets/creation_recap.dart';
import 'package:budgly/src/pages/tutorial/widgets/tutorial_step_badge.dart';
import 'package:budgly/src/pages/tutorial/widgets/tutorial_step_scaffold.dart';
import 'package:budgly/src/shared/ui/widgets/inputs/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BudgetStep extends ConsumerStatefulWidget {
  final VoidCallback onFinish;
  const BudgetStep({super.key, required this.onFinish});

  @override
  ConsumerState<BudgetStep> createState() => _BudgetStepState();
}

class _BudgetStepState extends ConsumerState<BudgetStep> {
  late final TextEditingController _revenueController;

  @override
  void initState() {
    super.initState();
    _revenueController = TextEditingController();
  }

  @override
  void dispose() {
    _revenueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = ref.watch(tutorialProvider);
    final currencyCode = ref.watch(
      profileSessionProvider.select((profile) => profile.currency),
    );
    final accountName = state.createdAccount?.name ?? '';

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
          CreationRecap(state: state, accountName: accountName),
          TextInput(
            controller: _revenueController,
            labelText: tr.revenue,
            type: InputType.currency,
            suffix: Padding(
              padding: EdgeInsets.only(right: BudglySpacing.sm),
              child: Icon(
                currencyCode.currencyIcon,
                size: 20,
                opticalSize: 14,
                color: theme.colorScheme.onSurface.withAlpha(155),
              ),
            ),
            textInputAction: TextInputAction.done,
            hotValidating: (v) {
              final amount = parseAmount(v ?? '');
              if (v != null &&
                  v.isNotEmpty &&
                  (amount == null || amount <= 0)) {
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
            await ref
                .read(tutorialProvider.notifier)
                .saveRevenue(_revenueController.text);
            widget.onFinish();
          },
          child: Text(tr.tutorialFinish),
        ),
      ),
    );
  }
}
