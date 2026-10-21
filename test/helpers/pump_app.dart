import 'package:budgly/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'test_backend_client_overrides.dart';

/// Minimal app wrapper for widget tests.
///
/// * sets deterministic surfaceSize per [size]
/// * provides French/English localizations
/// * light + dark themes available via [themeMode]
///
/// When [container] is given it becomes the root scope instead of a scope
/// built from `testBackendClientOverrides()`. Widgets pushed on the Navigator
/// (routes, bottom sheets, dialogs) are built *outside* a scope nested under
/// `home`, so tests that drive such routes must own the root container and put
/// every override there — otherwise the route resolves a different container
/// than the widget tree passed in.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(360, 740),
  ThemeMode themeMode = ThemeMode.light,
  Locale locale = const Locale('fr'),
  bool settle = true,
  ProviderContainer? container,
}) async {
  await tester.binding.setSurfaceSize(size);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    container != null
        ? UncontrolledProviderScope(
            container: container,
            child: _buildApp(child, themeMode, locale),
          )
        // Default: keep widget tests isolated from real Firebase/Supabase
        // singletons.
        : ProviderScope(
            overrides: testBackendClientOverrides(),
            child: _buildApp(child, themeMode, locale),
          ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  }
}

Widget _buildApp(Widget child, ThemeMode themeMode, Locale locale) {
  return MaterialApp(
    locale: locale,
    themeMode: themeMode,
    theme: ThemeData.light(useMaterial3: true),
    darkTheme: ThemeData.dark(useMaterial3: true),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('fr')],
    home: Scaffold(body: child),
  );
}

Future<void> pumpAppWithScaffold(
  WidgetTester tester,
  Widget body, {
  Size size = const Size(360, 740),
}) async => pumpApp(tester, body, size: size);
