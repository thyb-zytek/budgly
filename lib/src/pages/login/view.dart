import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/auth/auth_state.dart';
import 'package:budgly/src/core/errors/app_user_message.dart';
import 'package:budgly/src/core/view_models/view_model_selector.dart';
import 'package:budgly/src/core/navigation/navigation_helper.dart';
import 'package:budgly/src/pages/login/view_model.dart';
import 'package:budgly/src/pages/login/widgets/login_appbar.dart';
import 'package:budgly/src/pages/login/widgets/login_form_switcher.dart';
import 'package:budgly/src/pages/login/widgets/login_loading_page.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  late final LoginViewModel _viewModel = LoginViewModel(
    onAuthenticated: (user) async {
      if (!mounted) return;
      final destination = await _viewModel.resolvePostAuthDestination(user);
      if (!mounted) return;
      if (destination == AuthDestination.overview) {
        context.go(NavigationHelper.overviewPath, extra: user);
      } else {
        context.go(NavigationHelper.tutorialPath);
      }
    },
  );

  @override
  void initState() {
    super.initState();
    _viewModel.initializeFormType();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  String? _translateErrorMessage(AppLocalizations tr, AuthState state) {
    switch (state.errorCode) {
      case 'invalid-credential':
        return tr.invalidCredentials;
      case 'email-already-in-use':
        return tr.emailAlreadyInUse;
      case 'user-not-found':
        return tr.userNotFound;
      case 'canceled':
        return null;
      default:
        if (state.errorCode == null) return null;
        // Never surface a raw, unlocalized Firebase message to the user —
        // fall back to a generic, correctly-classified localized message.
        final key = classifyError(state.errorMessage ?? state.errorCode!);
        return AppUserMessage.error(key).resolve(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: ViewModelSelector<LoginViewModel, AuthState>(
            model: _viewModel,
            selector: (model) => model.state,
            builder: (context, state) {
              final isKeyboardOpen =
                  MediaQuery.of(context).viewInsets.bottom > 0;

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: BudglySpacing.lg,
                ).copyWith(top: isKeyboardOpen ? 64 : 112),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 24,
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      alignment: Alignment.topCenter,
                      child: LoginAppbar(isCompact: isKeyboardOpen),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: BudglySpacing.xl),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: state.isLoading
                            ? LoginLoadingView(
                                key: const ValueKey('loading'),
                                formType: state.formType,
                                isGoogleSignIn: state.isGoogleSignIn,
                              )
                            : Column(
                                key: const ValueKey('form'),
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                      if (state.errorCode != null &&
                                          _translateErrorMessage(tr, state) != null)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: BudglySpacing.lg,
                                      ),
                                      child: Text(
                                        _translateErrorMessage(tr, state)!,
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: theme.colorScheme.error,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                  LoginFormSwitcher(
                                    viewModel: _viewModel,
                                    formKey: _formKey,
                                    onEvent: (event) =>
                                        _viewModel.handleEvent(event),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
