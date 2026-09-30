import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/navigation/navigation_provider.dart';
import 'package:budgly/src/core/theme/material_theme.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:budgly/src/shared/ui/widgets/banners/sync_issue_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';

class BudglyApp extends ConsumerWidget {
  const BudglyApp({super.key});

  static const MaterialTheme _theme = MaterialTheme();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only rebuild MaterialApp.router (and re-run its whole subtree) when
    // themeMode or locale actually change, not on every ProfileSession
    // update (currentUser/hasLoaded/currency/... churn a lot during
    // startup while the profile is loading from cache then from network).
    final themeMode = ref.watch(
      profileSessionProvider.select((p) => p.themeMode),
    );
    final locale = ref.watch(profileSessionProvider.select((p) => p.locale));
    final router = ref.watch(appRouterProvider);
    return ScreenUtilPlusInit(
      designSize: const Size(427, 952),
      minTextAdapt: true,
      ensureScreenSize: false,
      builder: (context, child) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          restorationScopeId: 'budgly_app',
          scrollBehavior: const _BounceScrollBehavior(),
          theme: _theme.light(),
          darkTheme: _theme.dark(),
          themeMode: themeMode,
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('fr')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
          builder: (context, routerChild) {
            final mediaQuery = MediaQuery.of(context);
            final clampedTextScaler = TextScaler.linear(
              mediaQuery.textScaler.scale(1.0).clamp(0.8, 1.2),
            );

            return MediaQuery(
              data: mediaQuery.copyWith(textScaler: clampedTextScaler),
              child: Material(
                // Solid surface behind the top inset so the status-bar area
                // never shows a see-through hole over the page below.
                color: Theme.of(context).scaffoldBackgroundColor,
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      const SyncIssueBanner(),
                      Expanded(child: routerChild!),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _BounceScrollBehavior extends ScrollBehavior {
  const _BounceScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics();
}
