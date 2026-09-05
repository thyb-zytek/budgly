import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/shared/ui/widgets/banners/sync_issue_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/pump_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final syncManager = SyncManager.instance;
  final queue = SyncQueue.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    await syncManager.resetForTest();
    await queue.clear();
  });

  tearDown(() async {
    await syncManager.resetForTest();
    await queue.clear();
  });

  Future<void> pumpBanner(WidgetTester tester) async {
    await pumpApp(
      tester,
      const Material(
        child: Column(
          children: [
            SyncIssueBanner(),
          ],
        ),
      ),
    );

    await tester.pump();
  }

  testWidgets(
    'banner stays hidden when there are no stuck operations',
    (tester) async {
      await pumpBanner(tester);

      expect(find.byType(SyncIssueBanner), findsOneWidget);
      expect(find.text('Réessayer'), findsNothing);
      expect(find.byIcon(Icons.sync_problem_rounded), findsNothing);
    },
  );

  testWidgets(
    'flush returns immediately when no handler is registered',
    (tester) async {
      await pumpBanner(tester);

      await tester.runAsync(() async {
        await syncManager.flush(forceRetry: true);
      });

      await tester.pump();

      expect(find.text('Réessayer'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'banner remains stable after an empty synchronization pass',
    (tester) async {
      await pumpBanner(tester);

      await tester.runAsync(() async {
        await syncManager.flush();
      });

      await tester.pump();

      expect(find.byType(SyncIssueBanner), findsOneWidget);
      expect(find.text('Réessayer'), findsNothing);
    },
  );

  testWidgets(
    'retry action does not hang when synchronization is not initialized',
    (tester) async {
      await pumpBanner(tester);

      // No handler is registered and therefore SyncManager.flush() must
      // return immediately.
      //
      // This specifically protects the UI from a retry operation that could
      // otherwise leave the widget test waiting indefinitely.
      await tester.runAsync(() async {
        await syncManager.flush(forceRetry: true);
      });

      await tester.pump();

      expect(find.byType(SyncIssueBanner), findsOneWidget);
      expect(find.text('Réessayer'), findsNothing);
    },
  );
}
