import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/core/extensions/amount.dart';
import 'package:budgly/src/pages/overview/revenue_provider.dart';
import 'package:budgly/src/shared/ui/widgets/forms/form_actions.dart';
import 'package:budgly/src/shared/ui/widgets/inputs/currency_input.dart';
import 'package:flutter/material.dart';

class RevenueForm extends StatefulWidget {
  final RevenueState state;
  final String currencyCode;
  final VoidCallback onClose;
  final Future<void> Function(double value) onSave;

  const RevenueForm({
    super.key,
    required this.state,
    required this.currencyCode,
    required this.onClose,
    required this.onSave,
  });

  @override
  State<RevenueForm> createState() => _RevenueFormState();
}

class _RevenueFormState extends State<RevenueForm> {
  late final TextEditingController _controller;
  bool _prefilledFromEstimate = false;

  String _initialText() {
    if (widget.state.revenue > 0) {
      return widget.state.revenue.toStringAsFixed(0);
    }
    final inherited = widget.state.inheritedRevenue;
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

    final stillUntouched =
        _controller.text.isEmpty ||
        (_prefilledFromEstimate &&
            _controller.text ==
                oldWidget.state.inheritedRevenue?.toStringAsFixed(0));
    if (stillUntouched && widget.state.revenue <= 0) {
      final inherited = widget.state.inheritedRevenue;
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
    final value = parseAmount(_controller.text) ?? 0;
    await widget.onSave(value);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        BudglySpacing.lg,
        BudglySpacing.md,
        BudglySpacing.lg,
        0,
      ),
      child: Container(
        padding: EdgeInsets.all(BudglySpacing.lg),
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
              currencyCode: widget.currencyCode,
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
              destructiveCancel: true,
            ),
          ],
        ),
      ),
    );
  }
}
