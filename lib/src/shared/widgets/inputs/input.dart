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
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final void Function(String)? onChange;

  const TextInput({
    super.key,
    required this.controller,
    this.hotValidating,
    required this.labelText,
    this.hintText,
    this.helperText,
    this.errorText,
    this.focusNode,
    this.type = InputType.global,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onChange,
  });

  @override
  State<TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<TextInput> {
  bool focused = false;
  bool error = false;
  bool erasable = false;
  bool _obscurePassword = true;
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

  void displayCalendar() {
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
      case InputType.email:
        return [AutofillHints.email];
      case InputType.username:
        return [AutofillHints.newUsername, AutofillHints.username];
      case InputType.password:
        return [AutofillHints.password];
      default:
        return [];
    }
  }

  TextInputType getTextInputType() {
    switch (widget.type) {
      case InputType.email:
        return TextInputType.emailAddress;
      case InputType.username:
        return TextInputType.name;
      case InputType.password:
        return TextInputType.visiblePassword;
      case InputType.url:
        return TextInputType.url;
      default:
        return TextInputType.text;
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
          keyboardType: getTextInputType(),
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onFieldSubmitted,
          onTapOutside: (e) => _focusNode.unfocus(),
          onChanged: (v) {
            if (widget.onChange != null) {
              widget.onChange!(v);
            }
            if (v.isEmpty) {
              setState(() => erasable = false);
            } else {
              setState(() => erasable = true);
            }
          },
          onTap:
              widget.type == InputType.calendar
                  ? () => displayCalendar()
                  : null,
          controller: widget.controller,
          autocorrect: false,
          validator: (v) {
            String? result;
            if (widget.hotValidating != null) {
              result = widget.hotValidating!(v);
            }

            if (widget.type == InputType.currency &&
                v != null &&
                v.isNotEmpty &&
                result == null) {
              final match = RegExp(r'^-?\d*(?:[.,]\d+)?$').firstMatch(v);
              if (match == null) {
                result = tr.invalidCurrency;
              }
            }

            if (widget.type == InputType.calendar &&
                v != null &&
                v.isNotEmpty &&
                result == null) {
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
          obscureText: widget.type == InputType.password && _obscurePassword,
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
                widget.type == InputType.calendar
                    ? Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Icon(Icons.calendar_today),
                    )
                    : null,
            suffixIcon: _buildSuffixIcon(theme),
          ),
        ),
      ),
    );
  }

  Widget _buildSuffixIcon(ThemeData theme) {
    final List<Widget> suffixIcons = [];

    if (widget.type == InputType.currency) {
      suffixIcons.add(
        Padding(
          padding: EdgeInsets.only(top: 16),
          child: Text(
            NumberFormat.simpleCurrency(
              locale: Platform.localeName,
            ).currencySymbol,
            style: theme.textTheme.bodyLarge?.merge(
              TextStyle(
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.outlineVariant,
              ),
            ),
          ),
        ),
      );
    }

    if (widget.type == InputType.password) {
      final List<Widget> passwordIcons = [
        IconButton(
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_rounded
                : Icons.visibility_off_rounded,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ];

      if (erasable) {
        passwordIcons.add(
          IconButton(
            onPressed: () {
              setState(() => erasable = false);
              widget.controller.clear();
            },
            icon: Icon(Icons.close_rounded),
          ),
        );
      }

      suffixIcons.add(
        Row(mainAxisSize: MainAxisSize.min, children: passwordIcons),
      );
    } else if (erasable) {
      suffixIcons.add(
        IconButton(
          onPressed: () {
            setState(() => erasable = false);
            widget.controller.clear();
          },
          icon: Icon(Icons.close_rounded),
        ),
      );
    }

    if (suffixIcons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: suffixIcons,
    );
  }
}
