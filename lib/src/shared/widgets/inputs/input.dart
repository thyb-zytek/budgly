import 'dart:io';

import 'package:app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'constants.dart';

class TextInput extends StatefulWidget {
  final TextEditingController controller;
  final String? Function(String? value)? hotValidating;

  final String labelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;

  final FocusNode? focusNode;

  final InputType type;

  const TextInput({
    super.key,
    required this.controller,
    this.hotValidating,
    required this.labelText,
    this.hintText,
    this.helperText,
    this.errorText,
    this.focusNode,
    this.type = InputType.Default,
  });

  @override
  State<TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<TextInput> {
  bool focused = false;
  bool error = false;
  bool erasable = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    _focusNode = widget.focusNode ?? FocusNode();
    erasable = widget.controller.text.isNotEmpty;
    super.initState();
  }

  @override
  void didUpdateWidget(covariant TextInput oldWidget) {
    if (erasable != widget.controller.text.isNotEmpty) {
      setState(() => erasable = widget.controller.text.isNotEmpty);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void displayCalendar(BuildContext context) {
    showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    ).then((date) {
      if (date != null) {
        widget.controller.text = DateFormat.yMMMd(
          AppLocalizations.of(context)?.localeName,
        ).format(date);
        setState(() => erasable = true);
      }
    });
  }

  Iterable<String> getAutofillHints() {
    switch (widget.type) {
      case InputType.Email:
        return [AutofillHints.email];
      case InputType.Username:
        return [AutofillHints.newUsername, AutofillHints.username];
      case InputType.Password:
        return [AutofillHints.password];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    AppLocalizations tr = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.only(bottom: 8, left: 4, right: 4),
      child: FocusScope(
        child: TextFormField(
          autofillHints: getAutofillHints(),
          focusNode: _focusNode,
          onTapOutside: (e) => _focusNode.unfocus(),
          onChanged: (v) {
            if (v.isEmpty) {
              setState(() => erasable = false);
            } else {
              setState(() => erasable = true);
            }
          },
          onTap:
              widget.type == InputType.Calendar
                  ? () => displayCalendar(context)
                  : null,
          controller: widget.controller,
          autocorrect: false,
          validator: (v) {
            String? result;
            if (widget.hotValidating != null) {
              result = widget.hotValidating!(v);
            }

            if (widget.type == InputType.Currency && v != null && v.isNotEmpty && result == null) {
              final match = RegExp(r'^-?\d*(?:[.,]\d+)?$').firstMatch(v);
              if (match == null) {
                result = tr.invalidCurrency;
              }
            }

            if (widget.type == InputType.Calendar && v != null && v.isNotEmpty && result == null) {
              try {
                DateFormat.yMMMd(Platform.localeName).parseStrict(v);
              } on FormatException {
                result = tr.invalidDate;
              }
            }

            if (result != null) {
              setState(() => error = true);
            }
            return result;
          },
          style: theme.textTheme.bodyLarge,
          autovalidateMode: AutovalidateMode.disabled,
          obscureText: widget.type == InputType.Password,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            helperText: widget.helperText,
            errorText: widget.errorText,
            alignLabelWithHint: true,
            errorMaxLines: 3,
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            prefixIcon:
                widget.type == InputType.Calendar
                    ? Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Icon(Icons.calendar_today),
                    )
                    : null,
            suffixIcon:
                erasable
                    ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.type == InputType.Currency)
                          Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Text(
                              NumberFormat.simpleCurrency(locale: Platform.localeName).currencySymbol,
                              style: theme.textTheme.bodyLarge?.merge(
                                TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              ),
                            ),
                          ),
                        IconButton(
                          onPressed: () {
                            setState(() => erasable = false);
                            widget.controller.clear();
                          },
                          icon: Icon(Icons.close_rounded),
                        ),
                      ],
                    )
                    : widget.type == InputType.Currency
                    ? Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text(
                        NumberFormat.simpleCurrency(locale: Platform.localeName).currencySymbol,
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodyLarge?.merge(
                          TextStyle(
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                    )
                    : null,
          ),
        ),
      ),
    );
  }
}
