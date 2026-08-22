import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/input_styles.dart';
import 'package:flutter/material.dart';

class TextInput extends StatefulWidget {
  final TextEditingController controller;
  final String? Function(String? value)? hotValidating;

  final String labelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;

  final FocusNode? focusNode;
  final InputDecoration? decoration;

  final InputType type;
  final TextInputAction? textInputAction;
  final TextStyle? style;
  final bool? enabled;
  final void Function(String)? onFieldSubmitted;
  final void Function(String)? onChange;
  final Widget? suffix;

  const TextInput({
    super.key,
    required this.controller,
    this.hotValidating,
    required this.labelText,
    this.hintText,
    this.helperText,
    this.errorText,
    this.focusNode,
    this.decoration,
    this.type = InputType.text,
    this.textInputAction,
    this.style,
    this.enabled,
    this.onFieldSubmitted,
    this.onChange,
    this.suffix
  });

  @override
  State<TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<TextInput> {
  bool _hasText = false;
  bool _obscurePassword = true;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _hasText = widget.controller.text.isNotEmpty;
  }

  @override
  void didUpdateWidget(covariant TextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hasText = widget.controller.text.isNotEmpty;
    if (_hasText != hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _clearText() {
    setState(() => _hasText = false);
    widget.controller.clear();
  }

  void _onTextChanged(String value) {
    widget.onChange?.call(value);
    final hasText = value.isNotEmpty;
    if (_hasText != hasText) {
      setState(() => _hasText = hasText);
    }
  }

  InputDecoration _buildDecoration(ThemeData theme) {
  final baseDecoration = (widget.decoration ?? const InputDecoration()).copyWith(
    labelText: widget.labelText,
    hintText: widget.hintText,
    helperText: widget.helperText,
    errorText: widget.errorText,
    contentPadding: EdgeInsets.all(16)
  );

  return widget.type.decorate(
    baseDecoration,
    InputTypeContext(
      theme: theme,
      obscureText: _obscurePassword,
      onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
      showClearButton: _hasText,
      onClear: _clearText,
      suffix: widget.suffix,
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        autofillHints: widget.type.autofillHints,
        keyboardType: widget.type.keyboardType,
        textInputAction: widget.textInputAction,
        onFieldSubmitted: widget.onFieldSubmitted,
        onTapOutside: (_) => _focusNode.unfocus(),
        onChanged: _onTextChanged,
        onTap: widget.type == InputType.date
            ? () => pickInputDate(context, widget.controller, () {
                setState(() => _hasText = true);
              })
            : null,
        autocorrect: false,
        obscureText: widget.type.obscuresText && _obscurePassword,
        style: widget.style ?? theme.textTheme.bodyLarge,
        autovalidateMode: AutovalidateMode.disabled,
        validator: (value) {
          return widget.hotValidating?.call(value) ??
              widget.type.validateValue(value, tr);
        },
        decoration: _buildDecoration(theme),
      ),
    );
  }
}
