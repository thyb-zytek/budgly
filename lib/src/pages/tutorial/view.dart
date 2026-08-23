import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/navigation/navigation_helper.dart';
import 'package:budgly/src/pages/tutorial/view_model.dart';
import 'package:budgly/src/pages/tutorial/widgets/step_indicator.dart';
import 'package:budgly/src/pages/tutorial/widgets/welcome_step.dart';
import 'package:budgly/src/pages/tutorial/widgets/account_step.dart';
import 'package:budgly/src/pages/tutorial/widgets/category_step.dart';
import 'package:budgly/src/pages/tutorial/widgets/budget_step.dart';
import 'package:budgly/src/shared/ui/widgets/layout/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TutorialPage extends StatefulWidget {
  TutorialPage({super.key});

  @override
  State<TutorialPage> createState() => _TutorialPageState();
}

class _TutorialPageState extends State<TutorialPage> {
  late final TutorialViewModel _viewModel;
  PageController? _pageController;

  @override
  void initState() {
    super.initState();
    _viewModel = TutorialViewModel();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _goToOverview() async {
    await _viewModel.completeTutorial();
    if (mounted) {
      context.go(NavigationHelper.overviewPath);
    }
  }

  void _onNextStep() {
    _viewModel.nextStep();
    _pageController?.animateToPage(
      _viewModel.currentStep,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPreviousStep() {
    _viewModel.previousStep();
    _pageController?.animateToPage(
      _viewModel.currentStep,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        final tr = AppLocalizations.of(context)!;
        final theme = Theme.of(context);

        if (_viewModel.isInitializing) {
          return const Scaffold(body: AppLoadingIndicator());
        }

        _pageController ??= PageController(initialPage: _viewModel.currentStep);

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (_viewModel.canGoBack) {
              _onPreviousStep();
            } else {
              _showLogoutDialog(context, tr);
            }
          },
          child: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        StepIndicator(
                          currentStep: _viewModel.currentStep,
                          totalSteps: _viewModel.totalSteps,
                        ),
                        if (_viewModel.canGoBack)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    theme.colorScheme.surfaceContainerHigh,
                                shape: const CircleBorder(),
                              ),
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                size: 20,
                              ),
                              onPressed: _onPreviousStep,
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
                        WelcomeStep(onNext: _onNextStep),
                        AccountStep(viewModel: _viewModel, onNext: _onNextStep),
                        CategoryStep(
                          viewModel: _viewModel,
                          onNext: _onNextStep,
                        ),
                        BudgetStep(
                          viewModel: _viewModel,
                          onFinish: _goToOverview,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
              await _viewModel.signOut();
              if (context.mounted) {
                context.go(NavigationHelper.loginPath);
              }
            },
            child: Text(tr.logout),
          ),
        ],
      ),
    );
  }
}
