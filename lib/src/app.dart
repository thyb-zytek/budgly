import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/loading/progressive_loader.dart';
import 'package:budgly/src/core/navigation/navigation_helper.dart';
import 'package:budgly/src/core/theme/material_theme.dart';
import 'package:budgly/src/pages/error/service_unavailable.dart';
import 'package:budgly/src/services/categories/category_icons_service.dart';
import 'package:budgly/src/services/errors/error_service.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class BudglyApp extends StatefulWidget {
  const BudglyApp({super.key});

  @override
  State<BudglyApp> createState() => _BudglyAppState();
}

class _BudglyAppState extends State<BudglyApp> {
  final ProfileService _profileService = ProfileService.instance;
  final CategoryIconsService _categoryIconsService = CategoryIconsService.instance;
  final ErrorService _errorProvider = ErrorService.instance;

  @override
  void initState() {
    super.initState();
    _loadSecondaryData();
  }

  Future<void> _loadSecondaryData() async {
    await ProgressiveLoader.loadEssentialOnly(
      essentialData: () async {},
      secondaryData: () async {
        await _categoryIconsService.getIcons();
      },
      onProgress: (progress) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = MaterialTheme();

    return ListenableBuilder(
      listenable: Listenable.merge([_profileService, _errorProvider]),
      builder: (context, child) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          restorationScopeId: 'budgly_app',
          scrollBehavior: const _BounceScrollBehavior(),
          theme: theme.light(),
          darkTheme: theme.dark(),
          themeMode: _profileService.themeMode,
          locale: _profileService.locale,
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

class _BounceScrollBehavior extends ScrollBehavior {
  const _BounceScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics();
}
