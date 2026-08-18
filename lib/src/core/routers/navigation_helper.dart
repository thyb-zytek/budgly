import 'package:budgly/src/core/auth/auth_session.dart';
import 'package:budgly/src/pages/category_expenses/view.dart';
import 'package:budgly/src/pages/login/view.dart';
import 'package:budgly/src/pages/overview/view.dart';
import 'package:budgly/src/pages/settings/view.dart';
import 'package:budgly/src/pages/tutorial/view.dart';
import 'package:budgly/src/services/accounts.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:budgly/src/shared/widgets/bottom_navbar/bottom_navbar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NavigationHelper {
  static final NavigationHelper _instance = NavigationHelper._internal();

  static NavigationHelper get instance => _instance;

  static late final GoRouter router;

  static final GlobalKey<NavigatorState> parentNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> overviewTabNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> settingsTabNavigatorKey =
      GlobalKey<NavigatorState>();

  BuildContext get context =>
      router.routerDelegate.navigatorKey.currentContext!;

  GoRouterDelegate get routerDelegate => router.routerDelegate;

  GoRouteInformationParser get routeInformationParser =>
      router.routeInformationParser;

  static const String loginPath = '/login';
  static const String tutorialPath = '/tutorial';
  static const String overviewPath = '/overview';
  static const String settingsPath = '/settings';
  static const String categoryExpensesPath = '/overview/category';

  /// Builds the deep-link path to a category expenses page.
  static String buildCategoryExpensesPath(
    String accountId,
    String categoryId,
    Period? period,
  ) {
    final path = '$categoryExpensesPath/$accountId/$categoryId';
    if (period == null) return path;
    return '$path?year=${period.year}&month=${period.month}';
  }

  static Period _parsePeriod(GoRouterState state) {
    final year = int.tryParse(state.uri.queryParameters['year'] ?? '');
    final month = int.tryParse(state.uri.queryParameters['month'] ?? '');
    if (year == null || month == null || month < 1 || month > 12) {
      return Period.current();
    }
    return Period(year: year, month: month);
  }

  factory NavigationHelper() => _instance;

  NavigationHelper._internal() {
    final routes = [
      GoRoute(
        path: loginPath,
        pageBuilder: (context, state) {
          return getPage(child: const LoginPage(), state: state);
        },
      ),
      GoRoute(
        path: tutorialPath,
        pageBuilder: (context, state) {
          return getPage(child: TutorialPage(), state: state);
        },
      ),
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: parentNavigatorKey,
        branches: [
          StatefulShellBranch(
            navigatorKey: overviewTabNavigatorKey,
            routes: [
              GoRoute(
                path: overviewPath,
                pageBuilder: (context, state) =>
                    getPage(child: const OverviewPage(), state: state),
                routes: [
                  GoRoute(
                    path: 'category/:accountId/:categoryId',
                    pageBuilder: (context, state) {
                      return getPage(
                        child: CategoryExpensesPage(
                          accountId: state.pathParameters['accountId']!,
                          categoryId: state.pathParameters['categoryId']!,
                          period: _parsePeriod(state),
                        ),
                        state: state,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: settingsTabNavigatorKey,
            routes: [
              GoRoute(
                path: settingsPath,
                pageBuilder: (context, state) {
                  return getPage(child: const SettingsPage(), state: state);
                },
              ),
            ],
          ),
        ],
        pageBuilder:
            (
              BuildContext context,
              GoRouterState state,
              StatefulNavigationShell navigationShell,
            ) {
              return getPage(
                child: BottomNavBar(child: navigationShell),
                state: state,
              );
            },
      ),
    ];

    router = GoRouter(
      navigatorKey: parentNavigatorKey,
      initialLocation: loginPath,
      refreshListenable: AuthSessionNotifier.instance,
      routes: routes,
      redirect: (BuildContext context, GoRouterState state) async {
        final user = fb.FirebaseAuth.instance.currentUser;
        final isLoggingIn = state.matchedLocation == NavigationHelper.loginPath;

        if (user == null && !isLoggingIn) {
          return NavigationHelper.loginPath;
        }

        if (user != null && isLoggingIn) {
          if (!user.emailVerified) {
            return null;
          }
          try {
            await AccountsService.instance.loadAccounts();
            if (AccountsService.instance.accounts.isNotEmpty) {
              return NavigationHelper.overviewPath;
            } else {
              return NavigationHelper.tutorialPath;
            }
          } catch (_) {
            return NavigationHelper.overviewPath;
          }
        }

        return null;
      },
    );
  }

  static Page getPage({required Widget child, required GoRouterState state}) {
    return MaterialPage(
      key: state.pageKey,
      child: child,
      restorationId: state.pageKey.value,
    );
  }
}