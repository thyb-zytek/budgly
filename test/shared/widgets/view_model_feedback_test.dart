import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/errors/app_user_message.dart';
import 'package:budgly/src/core/view_models/base_view_model.dart';
import 'package:budgly/src/shared/ui/widgets/feedback/view_model_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestViewModel extends BaseViewModel {
  void queueSuccess(AppMessageKey key) =>
      setSuccessMessage(AppUserMessage.success(key));

  void queueError(AppMessageKey key) =>
      setError(Exception('test'), userMessage: AppUserMessage.error(key));

  void setLoadingForTest(bool loading) => setLoading(loading);
}

Widget _buildApp(_TestViewModel vm) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ViewModelFeedback(
        viewModel: vm,
        child: const Text('child'),
      ),
    ),
  );
}

void main() {
  group('ViewModelFeedback', () {
    testWidgets('renders child', (tester) async {
      final vm = _TestViewModel();
      await tester.pumpWidget(_buildApp(vm));
      expect(find.text('child'), findsOneWidget);
    });

    testWidgets('shows snackbar on success message', (tester) async {
      final vm = _TestViewModel();
      await tester.pumpWidget(_buildApp(vm));

      vm.queueSuccess(AppMessageKey.accountSaved);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('shows snackbar on error message', (tester) async {
      final vm = _TestViewModel();
      await tester.pumpWidget(_buildApp(vm));

      vm.queueError(AppMessageKey.networkError);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('does not show snackbar when no message queued', (tester) async {
      final vm = _TestViewModel();
      await tester.pumpWidget(_buildApp(vm));

      vm.setLoadingForTest(true);
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('consumes message so it is not shown twice', (tester) async {
      final vm = _TestViewModel();
      await tester.pumpWidget(_buildApp(vm));

      vm.queueSuccess(AppMessageKey.accountSaved);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SnackBar), findsOneWidget);

      // Trigger a rebuild — message should already be consumed
      vm.setLoadingForTest(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Only one snackbar (the original), not a duplicate
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('re-attaches listener when viewModel changes', (tester) async {
      final vm1 = _TestViewModel();
      final vm2 = _TestViewModel();

      await tester.pumpWidget(_buildApp(vm1));

      // Queue on vm1 — should show snackbar (listener attached)
      vm1.queueSuccess(AppMessageKey.accountSaved);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SnackBar), findsOneWidget);

      // Rebuild entire tree with vm2 — old state disposed, new state created
      // with vm2 listener. Verify vm2 works.
      await tester.pumpWidget(_buildApp(vm2));

      vm2.queueSuccess(AppMessageKey.categorySaved);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SnackBar), findsOneWidget);

      // Verify old vm1 no longer triggers snackbars (its state is disposed)
      vm1.queueSuccess(AppMessageKey.accountSaved);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Still only one snackbar from vm2 — vm1's message was not handled
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
