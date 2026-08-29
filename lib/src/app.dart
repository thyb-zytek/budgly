import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/navigation/navigation_helper.dart';
import 'package:budgly/src/core/theme/material_theme.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:budgly/src/shared/ui/widgets/banners/sync_issue_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class BudglyApp extends StatelessWidget {
  const BudglyApp({super.key});

  static final MaterialTheme _theme = MaterialTheme();

  @override
  Widget build(BuildContext context) {
    final profileService = ProfileService.instance;
    return ListenableBuilder(
      listenable: profileService,
      builder: (context, child) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          restorationScopeId: 'budgly_app',
          scrollBehavior: const _BounceScrollBehavior(),
          theme: _theme.light(),
          darkTheme: _theme.dark(),
          themeMode: profileService.themeMode,
          locale: profileService.locale,
          supportedLocales: const [Locale('en'), Locale('fr')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: NavigationHelper.router,
          builder: (context, routerChild) {
            final mediaQuery = MediaQuery.of(context);
            final clampedTextScaler = TextScaler.linear(
              mediaQuery.textScaler.scale(1.0).clamp(0.8, 1.2),
            );

            return MediaQuery(
              data: mediaQuery.copyWith(textScaler: clampedTextScaler),
              child: Column(
                children: [
                  const SyncIssueBanner(),
                  Expanded(child: routerChild!),
                ],
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
