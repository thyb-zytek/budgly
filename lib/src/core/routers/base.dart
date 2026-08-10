import 'package:budgly/src/core/auth/auth_session.dart';
import 'package:budgly/src/pages/login/view.dart';
import 'package:budgly/src/pages/overview/view.dart';
import 'package:budgly/src/pages/settings/view.dart';
import 'package:budgly/src/pages/tutorial/view.dart';
import 'package:budgly/src/shared/widgets/bottom_navbar/bottom_navbar.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
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
                pageBuilder:
                    (context, state) =>
                        getPage(child: const OverviewPage(), state: state),
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
        pageBuilder: (
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
      initialLocation: '/',
      refreshListenable: AuthSessionNotifier.instance,
      routes: routes,
      redirect: (BuildContext context, GoRouterState state) {
        final user = firebase.FirebaseAuth.instance.currentUser;

        if (state.matchedLocation == loginPath && user != null) {
          return tutorialPath;
        }

        if (user == null && state.matchedLocation != loginPath) {
          return loginPath;
        }

        if (user != null && state.matchedLocation == '/') {
          return tutorialPath;
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
