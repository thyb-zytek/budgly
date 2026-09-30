import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/auth/auth_state.dart';
import 'package:budgly/src/core/errors/app_user_message.dart';
import 'package:budgly/src/core/navigation/navigation_helper.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/pages/login/login_provider.dart';
import 'package:budgly/src/pages/login/widgets/login_appbar.dart';
import 'package:budgly/src/pages/login/widgets/login_form_switcher.dart';
import 'package:budgly/src/pages/login/widgets/login_loading_page.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _password2Controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(loginProvider.notifier).initializeFormType(),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _password2Controller.dispose();
    super.dispose();
  }

  void _changeFormType(AuthForm formType) {
    final current = ref.read(loginProvider).formType;
    final keepEmail =
        formType == AuthForm.resetPassword ||
        (formType == AuthForm.signIn && current == AuthForm.resetPassword);
    if (!keepEmail) _emailController.clear();
    _passwordController.clear();
    _password2Controller.clear();
    ref.read(loginProvider.notifier).changeFormType(formType);
  }

  Future<void> _handleAuthenticated(User user) async {
    final destination = await ref
        .read(loginProvider.notifier)
        .resolvePostAuthDestination(user);
    if (!mounted) return;
    if (destination == AuthDestination.overview) {
      context.go(NavigationHelper.overviewPath, extra: user);
    } else {
      context.go(NavigationHelper.tutorialPath);
    }
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
        final key = classifyError(state.errorMessage ?? state.errorCode!);
        return AppUserMessage.error(key).resolve(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;
    final state = ref.watch(loginProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: BudglySpacing.lg)
                .copyWith(
                  top: MediaQuery.of(context).viewInsets.bottom > 0 ? 64 : 112,
                ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 24,
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: LoginAppbar(
                    isCompact: MediaQuery.of(context).viewInsets.bottom > 0,
                  ),
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
                                  padding: EdgeInsets.symmetric(
                                    vertical: BudglySpacing.lg,
                                  ),
                                  child: Text(
                                    _translateErrorMessage(tr, state)!,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.error,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              LoginFormSwitcher(
                                state: state,
                                formKey: _formKey,
                                emailController: _emailController,
                                passwordController: _passwordController,
                                password2Controller: _password2Controller,
                                onChangeFormType: _changeFormType,
                                onSubmitSignIn: () async {
                                  final user = await ref
                                      .read(loginProvider.notifier)
                                      .signIn(
                                        email: _emailController.text,
                                        password: _passwordController.text,
                                      );
                                  if (user != null) {
                                    await _handleAuthenticated(user);
                                  }
                                },
                                onSubmitSignUp: () async {
                                  final user = await ref
                                      .read(loginProvider.notifier)
                                      .signUp(
                                        email: _emailController.text,
                                        password: _passwordController.text,
                                      );
                                  if (user != null) {
                                    await _handleAuthenticated(user);
                                  }
                                },
                                onResetPassword: () => ref
                                    .read(loginProvider.notifier)
                                    .resetPassword(_emailController.text),
                                onGoogleSignIn: () async {
                                  final user = await ref
                                      .read(loginProvider.notifier)
                                      .signInWithGoogle();
                                  if (user != null) {
                                    await _handleAuthenticated(user);
                                  }
                                },
                                onResendVerification: () => ref
                                    .read(loginProvider.notifier)
                                    .resendEmailVerification(),
                                onReload: () async {
                                  await ref
                                      .read(loginProvider.notifier)
                                      .reloadUser();
                                  final current = ref
                                      .read(loginProvider)
                                      .currentUser;
                                  if (current?.emailVerified == true &&
                                      current != null) {
                                    await _handleAuthenticated(current);
                                  }
                                },
                                onSignOut: () async {
                                  await ref
                                      .read(loginProvider.notifier)
                                      .signOut();
                                  _emailController.clear();
                                  _passwordController.clear();
                                  _password2Controller.clear();
                                },
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
