import 'dart:async';
import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/routers/navigation_helper.dart';
import 'package:budgly/src/pages/tutorial/view_model.dart';
import 'package:budgly/src/shared/widgets/loading/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TutorialPage extends StatefulWidget {
  TutorialPage({super.key});

  @override
  State<TutorialPage> createState() => _TutorialPageState();
}

class _TutorialPageState extends State<TutorialPage> {
  late final TutorialViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = TutorialViewModel();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }
  
  void _navigateToLogin() {
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        final tr = AppLocalizations.of(context)!;

        if (_viewModel.isChecking) {
          return const Scaffold(body: AppLoadingIndicator());
        }

        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  tr.tutorial,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    print("Logging out...");
                    await _viewModel.signOut();
                    print("Navigating to login...");
                    
                    if (!mounted) return;
                    
                    // Listen to auth state changes to detect when user is truly logged out
                    StreamSubscription? subscription;
                    subscription = FirebaseAuth.instance.authStateChanges().listen((user) {
                      print("Auth state changed, user is null: ${user == null}");
                      if (user == null) {
                        subscription?.cancel();
                        _navigateToLogin();
                      }
                    });
                    
                    // Fallback: navigate after 2 seconds if auth state doesn't change
                    await Future.delayed(const Duration(seconds: 2));
                    subscription.cancel();
                    print("Fallback: navigating to login");
                    _navigateToLogin();
                  },
                  child: Text(tr.logout),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    context.go(NavigationHelper.settingsPath);
                  },
                  child: Text(tr.settingsDev),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
