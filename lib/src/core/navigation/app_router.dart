import 'package:budgly/src/core/auth/auth_session.dart';
import 'package:budgly/src/core/navigation/app_routes.dart';
import 'package:budgly/src/core/navigation/route_guards.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/pages/category_expenses/view.dart';
import 'package:budgly/src/pages/login/view.dart';
import 'package:budgly/src/pages/overview/view.dart';
import 'package:budgly/src/pages/settings/view.dart';
import 'package:budgly/src/pages/tutorial/view.dart';
import 'package:budgly/src/shared/ui/widgets/bottom_navbar/bottom_navbar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppRouter {
  AppRouter._();

  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> overviewNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> settingsNavigatorKey =
      GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.login,
    refreshListenable: Listenable.merge([
      AuthSessionNotifier.instance,
      ProfileService.instance,
    ]),
    redirect: (context, state) => RouteGuards.authRedirect(state),
    routes: [
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => _page(const LoginPage(), state),
      ),
      GoRoute(
        path: AppRoutes.tutorial,
        pageBuilder: (context, state) => _page(TutorialPage(), state),
      ),
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: rootNavigatorKey,
        branches: [
          StatefulShellBranch(
            navigatorKey: overviewNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.overview,
                pageBuilder: (context, state) =>
                    _page(const OverviewPage(), state),
                routes: [
                  GoRoute(
                    path: 'category/:accountId/:categoryId',
                    pageBuilder: (context, state) {
                      return _page(
                        CategoryExpensesPage(
                          accountId: state.pathParameters['accountId']!,
                          categoryId: state.pathParameters['categoryId']!,
                          period: _parsePeriod(state),
                        ),
                        state,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: settingsNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                pageBuilder: (context, state) =>
                    _page(const SettingsPage(), state),
              ),
            ],
          ),
        ],
        pageBuilder: (context, state, navigationShell) => _page(
          BottomNavBar(child: navigationShell),
          state,
        ),
      ),
    ],
  );

  static Period _parsePeriod(GoRouterState state) {
    final year = int.tryParse(state.uri.queryParameters['year'] ?? '');
    final month = int.tryParse(state.uri.queryParameters['month'] ?? '');
    if (year == null || month == null || month < 1 || month > 12) {
      return Period.current();
    }
    return Period(year: year, month: month);
  }

  static Page<void> _page(Widget child, GoRouterState state) {
    return MaterialPage<void>(
      key: state.pageKey,
      child: child,
      restorationId: state.pageKey.value,
    );
  }
}
