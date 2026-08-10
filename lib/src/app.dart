import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/loading/progressive_loader.dart';
import 'package:budgly/src/core/routers/base.dart';
import 'package:budgly/src/core/theme/theme.dart';
import 'package:budgly/src/pages/error/service_unavailable.dart';
import 'package:budgly/src/services/category_icons.dart';
import 'package:budgly/src/services/preferences.dart';
import 'package:budgly/src/services/errors.dart';
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
  final ErrorService _errorProvider = ErrorService.instance;
  late ThemeMode _currentThemeMode;
  late Locale _currentLocale;

  @override
  void initState() {
    super.initState();
    _currentThemeMode = _preferencesService.themeMode;
    _currentLocale = _preferencesService.locale;
    _preferencesService.addListener(_handleThemeChange);
    _preferencesService.addListener(_handleLocaleChange);
    
    // Progressive loading: load icons in background after essential app init
    _loadSecondaryData();
  }
  
  Future<void> _loadSecondaryData() async {
    await ProgressiveLoader.loadEssentialOnly(
      essentialData: () async {
        // Essential: already loaded via _currentThemeMode and _currentLocale
      },
      secondaryData: () async {
        // Secondary: category icons can be loaded in background
        await _categoryIconsService.getIcons();
      },
      onProgress: (progress) {
        // Optional: track progress if needed
      },
    );
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

    return ListenableBuilder(
      listenable: _errorProvider,
      builder: (context, child) {
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
          builder: (context, routerChild) {
            if (_errorProvider.hasError) {
              return const ServiceUnavailableScreen();
            }
            return routerChild!;
          },
        );
      },
    );
  }
}
