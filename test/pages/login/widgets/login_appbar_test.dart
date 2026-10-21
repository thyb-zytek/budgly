import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/core/theme/material_theme.dart';
import 'package:budgly/src/pages/login/widgets/login_appbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:flutter_test/flutter_test.dart';

/// Logical size of the Android emulator used by the CI integration job.
///
/// The workflow creates the AVD without an explicit hardware profile, which
/// yields a 320dp wide screen. The startup integration test boots the real
/// application there, so the login screen must fit that width.
const Size _ciEmulatorSize = Size(320, 533);

Future<void> _loadSairaFont() async {
  final ByteData data = await rootBundle.load(
    'assets/fonts/saira/Saira-VariableFont_wdth,wght.ttf',
  );
  final FontLoader loader = FontLoader('Saira')..addFont(Future.value(data));
  await loader.load();
}

/// Application theme, built once.
///
/// The application builds its theme (a static final) while `BudglyApp` is
/// built, which happens *before* `MaterialApp.router` runs its builder and
/// configures ScreenUtil. The theme font sizes are therefore computed with the
/// authored values (48dp for `displayLarge`) and do not shrink on a narrow
/// screen, while the spacing tokens do. This test keeps that ordering.
ThemeData? _theme;

Future<void> _pumpLoginAppbar(
  WidgetTester tester, {
  required Size size,
  bool isCompact = false,
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
      theme: _theme,
      locale: const Locale('fr'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('fr')],
      home: Scaffold(
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: BudglySpacing.lg),
          child: LoginAppbar(isCompact: isCompact),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() async {
    await _loadSairaFont();
    _theme = const MaterialTheme().light();
  });

  setUp(() {
    // Same ScreenUtil configuration as the application (lib/src/app.dart),
    // resolved against the CI emulator size.
    ScreenUtilPlus.configure(
      data: const MediaQueryData(size: _ciEmulatorSize),
      designSize: const Size(427, 952),
      minTextAdapt: true,
      splitScreenMode: true,
    );
  });

  tearDown(() {
    // Restore the configuration shared by the other test files.
    ScreenUtilPlus.configure(
      data: const MediaQueryData(size: Size(360, 740)),
      designSize: const Size(360, 690),
      minTextAdapt: false,
      splitScreenMode: false,
    );
  });

  testWidgets('the brand row does not overflow on a narrow screen', (
    tester,
  ) async {
    await _pumpLoginAppbar(tester, size: _ciEmulatorSize);

    expect(tester.takeException(), isNull);
    expect(find.text('Budgly'), findsOneWidget);
  });

  testWidgets('the brand name is not truncated on a narrow screen', (
    tester,
  ) async {
    await _pumpLoginAppbar(tester, size: _ciEmulatorSize);

    final RenderParagraph title = tester.renderObject<RenderParagraph>(
      find.text('Budgly'),
    );
    expect(title.didExceedMaxLines, isFalse);
  });

  testWidgets('the brand row does not overflow in compact mode', (
    tester,
  ) async {
    await _pumpLoginAppbar(tester, size: _ciEmulatorSize, isCompact: true);

    expect(tester.takeException(), isNull);
  });
}
