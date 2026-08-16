import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/extensions/currency.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:budgly/src/core/theme/input_styles.dart';
import 'package:budgly/src/pages/overview/view_model.dart';
import 'package:budgly/src/shared/widgets/inputs/input.dart';
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

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.viewModel.revenue > 0
          ? widget.viewModel.revenue.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = double.tryParse(_controller.text.replaceAll(',', '.')) ?? 0;
    widget.viewModel.setRevenue(value);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
            TextInput(
              controller: _controller,
              labelText: tr.revenue,
              type: InputType.currency,
              suffix: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  widget.viewModel.currencyCode.currencyIcon,
                  size: 20,
                  opticalSize: 14,
                  color: theme.colorScheme.onSurface.withAlpha(155),
                ),
              ),
              textInputAction: TextInputAction.done,
              hotValidating: (v) {
                final amount = double.tryParse((v ?? '').replaceAll(',', '.'));
                if (amount == null || amount <= 0) return tr.amountInvalid;
                return null;
              },
            ),
            Row(
              spacing: 16,
              children: [
                Expanded(
                  child: FilledButton(
                    style: ButtonType.error.filledStyle(theme, dense: true),
                    onPressed: widget.onClose,
                    child: Text(tr.cancel),
                  ),
                ),
                Expanded(
                  child: FilledButton(
                    style: ButtonType.primary.filledStyle(theme, dense: true),
                    onPressed: _save,
                    child: Text(tr.validate),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
