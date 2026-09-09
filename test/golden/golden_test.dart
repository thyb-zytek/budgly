import 'dart:typed_data';

import 'package:budgly/src/shared/ui/widgets/layout/avatar.dart';
import 'package:budgly/src/shared/ui/widgets/layout/empty_state.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _TolerantGoldenFileComparator extends LocalFileComparator {
  _TolerantGoldenFileComparator(
    super.testFile, {
    required double precisionTolerance,
  }) : _precisionTolerance = precisionTolerance; // ignore: prefer_initializing_formals

  final double _precisionTolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final ComparisonResult result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );

    final bool passed = result.passed || result.diffPercent <= _precisionTolerance;
    if (passed) {
      result.dispose();
      return true;
    }

    final String error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  goldenFileComparator = _TolerantGoldenFileComparator(
    Uri.parse('test/golden/golden_test.dart'),
    precisionTolerance: 0.01,
  );

  const mobile = Size(360, 740);
  const tablet = Size(768, 1024);

  Future<void> pumpGolden(WidgetTester tester, Widget widget, Size size, Brightness brightness) async {
    await tester.binding.setSurfaceSize(size);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        darkTheme: ThemeData.dark(useMaterial3: true),
        themeMode: brightness == Brightness.light ? ThemeMode.light : ThemeMode.dark,
        home: Scaffold(body: Center(child: widget)),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Goldens - déterministes (light/dark, mobile/tablet)', () {
    testWidgets('EmptyState - empty - light mobile', (tester) async {
      await pumpGolden(tester, const EmptyState(icon: Icons.account_balance_wallet, title: 'Aucun compte', subtitle: 'Créez votre premier compte'), mobile, Brightness.light);
      await expectLater(find.byType(EmptyState), matchesGoldenFile('goldens/empty_state_light_mobile.png'));
    });

    testWidgets('EmptyState - empty - dark mobile', (tester) async {
      await pumpGolden(tester, const EmptyState(icon: Icons.account_balance_wallet, title: 'Aucun compte', subtitle: 'Créez votre premier compte'), mobile, Brightness.dark);
      await expectLater(find.byType(EmptyState), matchesGoldenFile('goldens/empty_state_dark_mobile.png'));
    });

    testWidgets('Avatar - light mobile', (tester) async {
      await pumpGolden(tester, Avatar(initial: 'C', size: 80, backgroundColor: Colors.blue, showEditBadge: true, onTap: () {}), mobile, Brightness.light);
      await expectLater(find.byType(Avatar), matchesGoldenFile('goldens/avatar_light_mobile.png'));
    });

    testWidgets('Avatar - dark tablet', (tester) async {
      await pumpGolden(tester, Avatar(initial: 'C', size: 80, backgroundColor: Colors.blue, showEditBadge: true, onTap: () {}), tablet, Brightness.dark);
      await expectLater(find.byType(Avatar), matchesGoldenFile('goldens/avatar_dark_tablet.png'));
    });

    testWidgets('Period label - populated - light mobile', (tester) async {
      const period = Period(year: 2026, month: 3);
      await pumpGolden(tester, Text(period.label('fr'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)), mobile, Brightness.light);
      await expectLater(find.text('Mars 2026'), matchesGoldenFile('goldens/period_label_light_mobile.png'));
    });

    testWidgets('PeriodSelector - loading shimmer placeholder (empty)', (tester) async {
      // Simulate empty period selector still deterministic size
      await pumpGolden(tester, const SizedBox(height: 60, child: Center(child: Text('Chargement...'))), mobile, Brightness.light);
      await expectLater(find.text('Chargement...'), matchesGoldenFile('goldens/loading_placeholder_light_mobile.png'));
    });
  });
}
