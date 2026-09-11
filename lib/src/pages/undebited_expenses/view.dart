import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/view_models/view_model_selector.dart';
import 'package:budgly/src/pages/undebited_expenses/view_model.dart';
import 'package:budgly/src/pages/undebited_expenses/widgets/undebited_expenses_content.dart';
import 'package:budgly/src/shared/ui/widgets/feedback/view_model_feedback.dart';
import 'package:flutter/material.dart';

class UndebitedExpensesPage extends StatefulWidget {
  final UndebitedExpensesViewModel? injectedViewModel;

  const UndebitedExpensesPage({super.key, this.injectedViewModel});

  @override
  State<UndebitedExpensesPage> createState() => _UndebitedExpensesPageState();
}

class _UndebitedExpensesPageState extends State<UndebitedExpensesPage> {
  late final UndebitedExpensesViewModel _viewModel;
  late final bool _ownsViewModel;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.injectedViewModel == null;
    _viewModel = widget.injectedViewModel ??
        UndebitedExpensesViewModel(onResolved: _autoPop);
    _viewModel.ensureDataLoaded();
  }

  @override
  void dispose() {
    if (_ownsViewModel) _viewModel.dispose();
    super.dispose();
  }

  /// A dedicated report page returns once there is nothing left to manage.
  void _autoPop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_viewModel.isEmpty) return;
      Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(tr.undebitedSheetTitle)),
      body: ViewModelFeedback(
        viewModel: _viewModel,
        child: ViewModelSelector<UndebitedExpensesViewModel, Object?>(
          model: _viewModel,
          selector: (model) => (
            model.occurrences,
            model.totalCount,
            model.totalAmount,
            model.isSelectionMode,
            model.currentPeriod,
            model.accounts,
            model.selectedAccountId,
            model.currencyCode,
            model.localeName,
            model.amountDecimalPlaces,
            model.isProcessing,
            model.busyKey,
          ),
          builder: (context, _) =>
              UndebitedExpensesContent(viewModel: _viewModel),
        ),
      ),
    );
  }
}