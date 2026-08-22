import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:budgly/src/pages/tutorial/widgets/tutorial_step_scaffold.dart';
import 'package:flutter/material.dart';

class WelcomeStep extends StatelessWidget {
  final VoidCallback onNext;

  const WelcomeStep({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;

    return TutorialStepScaffold(
      badge: TutorialStepBadge(
        size: 128,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: 280,
          height: 280,
          child: Image.asset('assets/images/logo.png'),
        ),
      ),
      title: tr.tutorialWelcome,
      subtitle: tr.tutorialWelcomeDescription,
      primaryAction: SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: ButtonType.primary.filledStyle(theme),
          onPressed: onNext,
          child: Text(
            tr.tutorialGetStarted,
            style: ButtonType.primary.labelStyle(theme),
          ),
        ),
      ),
    );
  }
}
