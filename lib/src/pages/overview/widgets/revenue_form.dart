import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/extensions/amount.dart';
import 'package:budgly/src/pages/overview/view_model.dart';
import 'package:budgly/src/shared/ui/widgets/forms/form_actions.dart';
import 'package:budgly/src/shared/ui/widgets/inputs/currency_input.dart';
import 'package:flutter/material.dart';

class RevenueForm extends StatefulWidget {
  final OverviewViewModel viewModel;
  final VoidCallback onClose;

  const RevenueForm({
    super.key,
    required this.viewModel,
    required this.onClose,
  });

  @override
  State<RevenueForm> createState() => _RevenueFormState();
}

class _RevenueFormState extends State<RevenueForm> {
  late final TextEditingController _controller;
  bool _prefilledFromEstimate = false;

  String _initialText() {
    if (widget.viewModel.revenue > 0) {
      return widget.viewModel.revenue.toStringAsFixed(0);
    }
    final inherited = widget.viewModel.inheritedRevenue;
    if (inherited != null && inherited > 0) {
      _prefilledFromEstimate = true;
      return inherited.toStringAsFixed(0);
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _initialText());
  }

  @override
  void didUpdateWidget(covariant RevenueForm oldWidget) {
    super.didUpdateWidget(oldWidget);

    final stillUntouched = _controller.text.isEmpty ||
        (_prefilledFromEstimate && _controller.text == oldWidget.viewModel.inheritedRevenue?.toStringAsFixed(0));
    if (stillUntouched && widget.viewModel.revenue <= 0) {
      final inherited = widget.viewModel.inheritedRevenue;
      if (inherited != null && inherited > 0) {
        _prefilledFromEstimate = true;
        _controller.text = inherited.toStringAsFixed(0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = parseAmount(
      _controller.text,
      decimalPlaces: widget.viewModel.amountDecimalPlaces,
    ) ?? 0;
    await widget.viewModel.setRevenue(value);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              CurrencyInput(
                controller: _controller,
                currencyCode: widget.viewModel.currencyCode,
                labelText: tr.revenue,
              ),
              if (_prefilledFromEstimate)
                Text(
                  tr.revenueEstimatedHint,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer.withAlpha(180),
                  ),
                ),
              FormActions(
                onCancel: widget.onClose,
                onSubmit: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
