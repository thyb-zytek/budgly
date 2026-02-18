import 'package:app/l10n/app_localizations.dart';
import 'package:app/src/core/routers/base.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/services/category_icons.dart';
import 'package:app/src/services/preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class BudglyApp extends StatefulWidget {
  const BudglyApp({super.key});

  @override
  State<BudglyApp> createState() => _BudglyAppState();
}

class _BudglyAppState extends State<BudglyApp> {
  final PreferencesService _preferencesService = PreferencesService();
  final CategoryIconsService _categoryIconsService =
      CategoryIconsService.instance;
  late ThemeMode _currentThemeMode;
  late Locale _currentLocale;

  @override
  void initState() {
    super.initState();
    PreferencesService.init();
    _categoryIconsService.getIcons();
    _currentThemeMode = _preferencesService.themeMode;
    _currentLocale = _preferencesService.locale;
    _preferencesService.addListener(_handleThemeChange);
    _preferencesService.addListener(_handleLocaleChange);
  }

  @override
  void dispose() {
    _preferencesService.removeListener(_handleThemeChange);
    _preferencesService.removeListener(_handleLocaleChange);
    super.dispose();
  }

  void _handleThemeChange() =>
      setState(() => _currentThemeMode = _preferencesService.themeMode);

  void _handleLocaleChange() =>
      setState(() => _currentLocale = _preferencesService.locale);

  @override
  Widget build(BuildContext context) {
    final theme = MaterialTheme();

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      restorationScopeId: 'budgly_app',
      theme: theme.light(),
      darkTheme: theme.dark(),
      themeMode: _currentThemeMode,
      locale: _currentLocale,
      supportedLocales: const [Locale('en'), Locale('fr')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: NavigationHelper.router,
    );
  }
}
