import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/pages/tutorial/widgets/tutorial_step_badge.dart';
import 'package:budgly/src/pages/tutorial/widgets/tutorial_step_scaffold.dart';
import 'package:flutter/material.dart';

class WelcomeStep extends StatelessWidget {
  final VoidCallback onNext;

  const WelcomeStep({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;

    return TutorialStepScaffold(
      badge: TutorialStepBadge(
        size: 128,
        child: SizedBox(
          width: 280,
          height: 280,
          child: Image.asset('assets/images/logo.webp'),
        ),
      ),
      title: tr.tutorialWelcome,
      subtitle: tr.tutorialWelcomeDescription,
      primaryAction: SizedBox(
        width: double.infinity,
        child: FilledButton(
                    onPressed: onNext,
          child: Text(
            tr.tutorialGetStarted,
          ),
        ),
      ),
    );
  }
}
