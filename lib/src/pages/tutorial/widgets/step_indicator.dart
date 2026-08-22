import 'package:budgly/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const StepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: AppLocalizations.of(context)!
          .tutorialStepProgress(currentStep + 1, totalSteps),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(totalSteps, (index) {
          final isActive = index == currentStep;
          final isPast = index < currentStep;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            // L'étape active s'allonge élégamment en pilule, dans le même
            // tempo que la transition du PageView pour un mouvement cohérent.
            width: isActive ? 28 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive
                  ? theme.colorScheme.primary
                  : isPast
                      ? theme.colorScheme.primary.withAlpha(120)
                      : theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(4),
              // Halo discret sous la pilule active : attire l'œil sans bruit.
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withAlpha(70),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
          );
        }),
      ),
    );
  }
}
