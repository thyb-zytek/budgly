import 'package:budgly/src/core/navigation/app_routes.dart';
import 'package:budgly/src/core/navigation/route_guards.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/pages/category_expenses/view.dart';
import 'package:budgly/src/pages/login/view.dart';
import 'package:budgly/src/pages/overview/view.dart';
import 'package:budgly/src/pages/undebited_expenses/view.dart';
import 'package:budgly/src/pages/settings/view.dart';
import 'package:budgly/src/pages/tutorial/view.dart';
import 'package:budgly/src/shared/ui/widgets/bottom_navbar/bottom_navbar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppRouter {
  AppRouter({required ChangeNotifier authSession})
    : router = _createRouter(authSession);

  final GoRouter router;

  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> overviewNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> settingsNavigatorKey =
      GlobalKey<NavigatorState>();

  static GoRouter _createRouter(ChangeNotifier authSession) => GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.login,
    refreshListenable: authSession,
    redirect: (context, state) {
      final profileSession = ProviderScope.containerOf(
        context,
      ).read(profileSessionProvider);
      return RouteGuards.decideRedirect(
        location: state.matchedLocation,
        profileUser: profileSession.currentUser,
        hasLoaded: profileSession.hasLoaded,
      );
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => _page(const LoginPage(), state),
      ),
      GoRoute(
        path: AppRoutes.tutorial,
        pageBuilder: (context, state) => _page(const TutorialPage(), state),
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
                    path: 'undebited',
                    pageBuilder: (context, state) =>
                        _page(const UndebitedExpensesPage(), state),
                  ),
                  GoRoute(
                    path: 'category/:accountId/:categoryId',
                    pageBuilder: (context, state) {
                      return _page(
                        CategoryExpensesPage(
                          accountId: state.pathParameters['accountId']!,
                          categoryId: state.pathParameters['categoryId']!,
                          period: parsePeriod(state.uri),
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
        pageBuilder: (context, state, navigationShell) =>
            _page(BottomNavBar(child: navigationShell), state),
      ),
    ],
  );

  static Period parsePeriod(Uri uri) {
    final year = int.tryParse(uri.queryParameters['year'] ?? '');
    final month = int.tryParse(uri.queryParameters['month'] ?? '');
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
