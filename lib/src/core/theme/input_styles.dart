import 'dart:io';

import 'package:budgly/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum InputType { text, email, password, currency, date, number, url }

class InputTypeContext {
  final ThemeData theme;
  final bool obscureText;
  final VoidCallback onToggleObscure;
  final bool showClearButton;
  final VoidCallback onClear;
  final Widget? suffix;

  const InputTypeContext({
    required this.theme,
    required this.obscureText,
    required this.onToggleObscure,
    required this.showClearButton,
    required this.onClear,
    this.suffix,
  });
}

extension InputTypeStyles on InputType {
  TextInputType get keyboardType => switch (this) {
    InputType.email => TextInputType.emailAddress,
    InputType.password => TextInputType.visiblePassword,
    InputType.url => TextInputType.url,
    InputType.number ||
    InputType.currency => const TextInputType.numberWithOptions(decimal: true),
    _ => TextInputType.text,
  };

  Iterable<String> get autofillHints => switch (this) {
    InputType.email => const [AutofillHints.email, AutofillHints.username],
    InputType.password => const [AutofillHints.password],
    _ => const [],
  };

  bool get obscuresText => this == InputType.password;

  String? validateValue(String? value, AppLocalizations tr) {
    if (value == null || value.isEmpty) return null;

    return switch (this) {
      InputType.currency =>
        RegExp(r'^-?\d*(?:[.,]\d+)?$').hasMatch(value)
            ? null
            : tr.invalidCurrency,
      InputType.date => _validateDate(value, tr),
      _ => null,
    };
  }

  String? _validateDate(String value, AppLocalizations tr) {
    try {
      DateFormat.yMMMd(Platform.localeName).parseStrict(value);
      return null;
    } on FormatException {
      return tr.invalidDate;
    }
  }

  InputDecoration decorate(InputDecoration base, InputTypeContext context) {
    Widget? prefixIcon;
    final suffixWidgets = <Widget>[];

    if (this == InputType.date) {
      prefixIcon = const Padding(
        padding: EdgeInsets.only(top: 16),
        child: Icon(Icons.calendar_today),
      );
    }

    if (this == InputType.password) {
      suffixWidgets.add(
        IconButton(
          onPressed: context.onToggleObscure,
          icon: Icon(
            context.obscureText
                ? Icons.visibility_rounded
                : Icons.visibility_off_rounded,
            color: context.theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (context.suffix != null) {
      suffixWidgets.add(context.suffix!);
    }

    if (context.showClearButton) {
      suffixWidgets.add(
        IconButton(
          icon: const Icon(Icons.clear, size: 20),
          onPressed: context.onClear,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      );
    }

    return base.copyWith(
      prefixIcon: prefixIcon ?? base.prefixIcon,
      suffixIcon: suffixWidgets.isEmpty
          ? base.suffixIcon
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: suffixWidgets,
            ),
    );
  }
}

Future<void> pickInputDate(
  BuildContext context,
  TextEditingController controller,
  VoidCallback onPicked,
) async {
  final date = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime.now(),
    lastDate: DateTime(2100),
  );

  if (!context.mounted || date == null) return;

  controller.text = DateFormat.yMMMd(
    AppLocalizations.of(context)?.localeName,
  ).format(date);
  onPicked();
}
