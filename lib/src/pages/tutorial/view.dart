import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/navigation/navigation_helper.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/core/theme/snackbar.dart';
import 'package:budgly/src/pages/tutorial/tutorial_provider.dart';
import 'package:budgly/src/pages/tutorial/widgets/account_step.dart';
import 'package:budgly/src/pages/tutorial/widgets/budget_step.dart';
import 'package:budgly/src/pages/tutorial/widgets/category_step.dart';
import 'package:budgly/src/pages/tutorial/widgets/step_indicator.dart';
import 'package:budgly/src/pages/tutorial/widgets/welcome_step.dart';
import 'package:budgly/src/shared/ui/widgets/layout/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TutorialPage extends ConsumerStatefulWidget {
  const TutorialPage({super.key});

  @override
  ConsumerState<TutorialPage> createState() => _TutorialPageState();
}

class _TutorialPageState extends ConsumerState<TutorialPage> {
  PageController? _pageController;

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _goToOverview() async {
    await ref.read(tutorialProvider.notifier).completeTutorial();
    if (mounted) context.go(NavigationHelper.overviewPath);
  }

  void _goToStep(int step) {
    _pageController?.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tutorialProvider);
    final notifier = ref.read(tutorialProvider.notifier);
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (state.isInitializing) {
      return const Scaffold(body: AppLoadingIndicator());
    }

    _pageController ??= PageController(initialPage: state.currentStep);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (state.canGoBack) {
          notifier.previousStep();
          _goToStep(state.currentStep - 1);
        } else {
          _showLogoutDialog(context, tr);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(BudglySpacing.md),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    StepIndicator(
                      currentStep: state.currentStep,
                      totalSteps: state.totalSteps,
                    ),
                    if (state.canGoBack)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHigh,
                            shape: const CircleBorder(),
                          ),
                          icon: const Icon(Icons.arrow_back_rounded, size: 20),
                          onPressed: () {
                            notifier.previousStep();
                            _goToStep(state.currentStep - 1);
                          },
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController!,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    WelcomeStep(
                      onNext: () {
                        notifier.nextStep();
                        _goToStep(state.currentStep + 1);
                      },
                    ),
                    AccountStep(
                      onNext: () {
                        notifier.nextStep();
                        _goToStep(state.currentStep + 1);
                      },
                    ),
                    CategoryStep(
                      onNext: () {
                        notifier.nextStep();
                        _goToStep(state.currentStep + 1);
                      },
                    ),
                    BudgetStep(onFinish: _goToOverview),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AppLocalizations tr) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr.logout),
        content: Text(tr.tutorialLogoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr.cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await ref.read(tutorialProvider.notifier).signOut();
                if (context.mounted) context.go(NavigationHelper.loginPath);
              } catch (_) {
                if (context.mounted) {
                  showAppSnackBar(
                    context,
                    message: tr.errorUnknown,
                    type: SnackBarType.error,
                  );
                }
              }
            },
            child: Text(tr.logout),
          ),
        ],
      ),
    );
  }
}
