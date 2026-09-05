import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/shared/ui/widgets/banners/sync_issue_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final syncManager = SyncManager.instance;

  setUp(() async {
    await syncManager.resetForTest();
  });

  tearDown(() async {
    await syncManager.resetForTest();
  });

  testWidgets(
    'hidden when there are no stuck operations',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SyncIssueBanner(),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(SyncIssueBanner), findsOneWidget);

      // The banner itself is present, but it must render no visible content.
      expect(find.byIcon(Icons.sync_problem_rounded), findsNothing);
      expect(find.text('Retry'), findsNothing);
    },
  );

  testWidgets(
    'does not hang when retry is triggered without a registered handler',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SyncIssueBanner(),
          ),
        ),
      );

      await tester.pump();

      // There is deliberately no handler registered here.
      //
      // SyncManager.flush() must return immediately when no handlers exist.
      // This test protects the banner from accidentally waiting forever for
      // a synchronization mechanism that is not initialized.
      await tester.runAsync(() async {
        await syncManager.flush(forceRetry: true);
      });

      await tester.pump();

      expect(find.byType(SyncIssueBanner), findsOneWidget);
    },
  );

  testWidgets(
    'banner remains hidden when sync queue is empty',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SyncIssueBanner(),
          ),
        ),
      );

      await tester.pump();

      expect(find.byIcon(Icons.sync_problem_rounded), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Retry'), findsNothing);
    },
  );
}
