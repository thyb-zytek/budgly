import 'package:budgly/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal app wrapper for widget tests.
///
/// * sets deterministic surfaceSize per [size]
/// * provides French/English localizations
/// * light + dark themes available via [themeMode]
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(360, 740),
  ThemeMode themeMode = ThemeMode.light,
  Locale locale = const Locale('fr'),
  bool settle = true,
}) async {
  await tester.binding.setSurfaceSize(size);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
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
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  }
}

Future<void> pumpAppWithScaffold(
  WidgetTester tester,
  Widget body, {
  Size size = const Size(360, 740),
}) async => pumpApp(tester, body, size: size);
