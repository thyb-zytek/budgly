import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/pages/overview/view_model.dart';
import 'package:budgly/src/shared/ui/widgets/form_actions.dart';
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

  Future<void> _save() async {
    final value = double.tryParse(_controller.text.replaceAll(',', '.')) ?? 0;
    await widget.viewModel.setRevenue(value);
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
            CurrencyInput(
              controller: _controller,
              currencyCode: widget.viewModel.currencyCode,
              labelText: tr.revenue,
            ),
            FormActions(
              onCancel: widget.onClose,
              onSubmit: _save,
            ),
          ],
        ),
      ),
    );
  }
}
