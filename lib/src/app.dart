import 'package:app/l10n/app_localizations.dart';
import 'package:app/src/core/routers/base.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class BudglyApp extends StatelessWidget {
  const BudglyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = View.of(context).platformDispatcher.platformBrightness;

    MaterialTheme theme = MaterialTheme();

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale('fr'), Locale('en')],
      restorationScopeId: 'budgly_app',
      theme: theme.light(),
      darkTheme: theme.light(),
      routerConfig: NavigationHelper.router,
    );
  }
}
