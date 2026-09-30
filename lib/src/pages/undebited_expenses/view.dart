import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/pages/undebited_expenses/undebited_expenses_provider.dart';
import 'package:budgly/src/pages/undebited_expenses/widgets/swipe_hint_wrapper.dart';
import 'package:budgly/src/pages/undebited_expenses/widgets/undebited_expenses_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budgly/src/shared/ui/widgets/feedback/riverpod_feedback.dart';

class UndebitedExpensesPage extends ConsumerStatefulWidget {
  const UndebitedExpensesPage({super.key});

  @override
  ConsumerState<UndebitedExpensesPage> createState() =>
      _UndebitedExpensesPageState();
}

class _UndebitedExpensesPageState extends ConsumerState<UndebitedExpensesPage> {
  final GlobalKey<UndebitedSwipeHintWrapperState> _swipeHintKey =
      GlobalKey<UndebitedSwipeHintWrapperState>();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(undebitedExpensesProvider.notifier).ensureDataLoaded(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final state = ref.watch(undebitedExpensesProvider);

    ref.listen(undebitedExpensesProvider.select((state) => state.isEmpty), (
      previous,
      next,
    ) {
      if (previous == true || next != true) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(undebitedExpensesProvider).isEmpty) {
          Navigator.of(context).pop();
        }
      });
    });

    return Scaffold(
      appBar: AppBar(title: Text(tr.undebitedSheetTitle)),
      body: RiverpodFeedback(
        messageListenable: undebitedExpensesProvider.select(
          (state) => state.status.pendingMessage,
        ),
        onConsume: (ref) =>
            ref.read(undebitedExpensesProvider.notifier).consumeMessage(),
        child: UndebitedExpensesContent(
          state: state,
          notifier: ref.read(undebitedExpensesProvider.notifier),
          swipeHintKey: _swipeHintKey,
        ),
      ),
    );
  }
}
