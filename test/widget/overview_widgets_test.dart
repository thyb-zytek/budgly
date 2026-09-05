import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/view_models/view_model_selector.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/pages/overview/widgets/period_selector.dart';
import 'package:budgly/src/shared/ui/widgets/layout/avatar.dart';
import 'package:budgly/src/shared/ui/widgets/layout/empty_state.dart';
import 'package:budgly/src/shared/ui/widgets/inputs/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

class _PeriodVm extends ChangeNotifier {
  _PeriodVm(this._period);
  Period _period;

  Period get period => _period;

  set period(Period value) {
    _period = value;
    notifyListeners();
  }
}

void main() {
  group('Overview widgets', () {
    testWidgets('PeriodSelector affiche le label du mois et permet navigation', (tester) async {
      const march = Period(year: 2026, month: 3);
      Period? selected;
      await pumpApp(
        tester,
        Builder(
          builder: (context) => CustomScrollView(
            slivers: [
              SliverPersistentHeader(
                delegate: PeriodSelector(
                  period: march,
                  minPeriod: const Period(year: 2025, month: 1),
                  maxPeriod: const Period(year: 2027, month: 12),
                  revision: 0,
                  theme: Theme.of(context),
                  onChanged: (p) => selected = p,
                ),
              ),
            ],
          ),
        ),
      );

      expect(find.textContaining('Mars'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pump();
      expect(selected, const Period(year: 2026, month: 2));

      selected = null;
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pump();
      expect(selected, const Period(year: 2026, month: 4));
    });

    testWidgets('PeriodSelector désactive la navigation aux bornes', (tester) async {
      const min = Period(year: 2026, month: 3);
      await pumpApp(
        tester,
        Builder(
          builder: (context) => CustomScrollView(
            slivers: [
              SliverPersistentHeader(
                delegate: PeriodSelector(
                  period: min,
                  minPeriod: min,
                  maxPeriod: const Period(year: 2026, month: 12),
                  revision: 0,
                  theme: Theme.of(context),
                  onChanged: (_) {},
                ),
              ),
            ],
          ),
        ),
      );
      final leftButton = tester.widget<IconButton>(find.byIcon(Icons.chevron_left_rounded).evaluate().first.widget is IconButton ? find.byType(IconButton).first : find.byType(IconButton).first);
      // The left nav should be disabled (onPressed null) when at min
      expect(leftButton.onPressed, isNull);
    });

    testWidgets('Avatar affiche initial et badge edit', (tester) async {
      await pumpApp(
        tester,
        Avatar(initial: 'A', size: 45, showEditBadge: true, onTap: () {}),
      );
      expect(find.text('A'), findsOneWidget);
      expect(find.byIcon(Icons.photo_camera_rounded), findsOneWidget);
    });

    testWidgets('EmptyState affiche titre et icône', (tester) async {
      await pumpApp(
        tester,
        const EmptyState(icon: Icons.account_balance_wallet, title: 'Aucun compte', subtitle: 'Créez votre premier compte'),
      );
      expect(find.text('Aucun compte'), findsOneWidget);
      expect(find.text('Créez votre premier compte'), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_wallet), findsOneWidget);
    });

    testWidgets('TextInput affiche label et gère le clear', (tester) async {
      final controller = TextEditingController(text: 'Hello');
      await pumpApp(
        tester,
        TextInput(controller: controller, labelText: 'Nom'),
      );
      expect(find.text('Nom'), findsOneWidget);
      expect(find.text('Hello'), findsOneWidget);
      // clear button should appear when hasText true (type text shows clear)
      await tester.enterText(find.byType(TextFormField), '');
      await tester.pump();
      expect(controller.text, isEmpty);
    });

    testWidgets('PeriodSelector responsive: mobile vs tablet', (tester) async {
      const period = Period(year: 2026, month: 6);
      Widget page() => Builder(
            builder: (context) => CustomScrollView(
              slivers: [
                SliverPersistentHeader(
                  delegate: PeriodSelector(
                    period: period,
                    minPeriod: const Period(year: 2025, month: 1),
                    maxPeriod: const Period(year: 2027, month: 12),
                    revision: 1,
                    theme: Theme.of(context),
                    onChanged: (_) {},
                  ),
                ),
              ],
            ),
          );
      await pumpApp(tester, page(), size: const Size(360, 740));
      expect(find.textContaining('Juin'), findsOneWidget);
      await pumpApp(tester, page(), size: const Size(768, 1024));
      expect(find.textContaining('Juin'), findsOneWidget);
    });

    testWidgets('PeriodSelector suivre le thème sans changer de période',
        (tester) async {
      final model = _PeriodVm(const Period(year: 2026, month: 7));
      final mode = ValueNotifier<ThemeMode>(ThemeMode.light);
      final lightTheme = ThemeData.light(useMaterial3: true);
      final darkTheme = ThemeData.dark(useMaterial3: true);

      final lightBg = lightTheme.scaffoldBackgroundColor;
      final darkBg = darkTheme.scaffoldBackgroundColor;
      expect(darkBg, isNot(lightBg));

      Future<void> pump() async {
        await tester.pumpWidget(
          MaterialApp(
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: mode.value,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('fr')],
            home: Scaffold(
              body: CustomScrollView(
                slivers: [
                  ViewModelSelector<_PeriodVm, Period>(
                    model: model,
                    selector: (m) => m.period,
                    builder: (context, value) {
                      final theme = Theme.of(context);
                      return SliverPersistentHeader(
                        pinned: true,
                        delegate: PeriodSelector(
                          period: value,
                          minPeriod: const Period(year: 2026, month: 1),
                          maxPeriod: const Period(year: 2026, month: 12),
                          revision: value.hashCode,
                          theme: theme,
                          onChanged: (p) => model.period = p,
                        ),
                      );
                    },
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 600)),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      Color headerColor() => tester
          .widget<Material>(
            find
                .ancestor(
                  of: find.textContaining('2026'),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color!;

      await pump();
      expect(headerColor(), lightBg);

      // Changing the theme must repaint the pinned header without any
      // period navigation.
      mode.value = ThemeMode.dark;
      await pump();
      expect(headerColor(), darkBg);

      // And the label still shows the same period.
      expect(find.textContaining('2026'), findsOneWidget);
    });
  });
}
