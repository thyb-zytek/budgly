import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/auth/auth_event.dart';
import 'package:budgly/src/core/auth/auth_state.dart';
import 'package:budgly/src/core/routers/navigation_helper.dart';
import 'package:budgly/src/pages/login/view_model.dart';
import 'package:budgly/src/pages/login/widgets/login_appbar.dart';
import 'package:budgly/src/pages/login/widgets/login_form_switcher.dart';
import 'package:budgly/src/pages/login/widgets/login_loading_page.dart';
import 'package:budgly/src/services/accounts.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final LoginViewModel _viewModel = LoginViewModel(
    onAuthenticated: (user) async {
      if (!mounted) return;
      try {
        await AccountsService.instance.loadAccounts();
        if (!mounted) return;
        if (AccountsService.instance.accounts.isNotEmpty) {
          context.go(NavigationHelper.overviewPath, extra: user);
        } else {
          context.go(NavigationHelper.tutorialPath);
        }
      } catch (_) {
        if (mounted) context.go(NavigationHelper.tutorialPath);
      }
    },
  );

  @override
  void initState() {
    super.initState();
    _viewModel.handleEvent(
      AuthEventParams(
        type: AuthEvent.changeFormType,
        formType: AuthForm.signUp,
      ),
    );
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  String? _translateErrorMessage(AppLocalizations tr) {
    switch (_viewModel.state.errorCode) {
      case 'invalid-credential':
        return tr.invalidCredentials;
      case 'email-already-in-use':
        return tr.emailAlreadyInUse;
      case 'user-not-found':
        return tr.userNotFound;
      case 'canceled':
        return null;
      default:
        return _viewModel.state.errorMessage ?? tr.commonError;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: ListenableBuilder(
            listenable: _viewModel,
            builder: (context, child) {
              final isKeyboardOpen =
                  MediaQuery.of(context).viewInsets.bottom > 0;

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
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
                      padding: EdgeInsets.only(top: 24),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: _viewModel.state.isLoading
                            ? LoginLoadingView(
                                key: const ValueKey('loading'),
                                formType: _viewModel.state.formType,
                                isGoogleSignIn: _viewModel.state.isGoogleSignIn,
                              )
                            : Column(
                                key: const ValueKey('form'),
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_viewModel.state.errorCode != null &&
                                      _translateErrorMessage(tr) != null)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: Text(
                                        _translateErrorMessage(tr)!,
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
