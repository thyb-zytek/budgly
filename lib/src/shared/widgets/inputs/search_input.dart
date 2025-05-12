import 'package:app/src/shared/widgets/inputs/input.dart';
import 'package:app/src/shared/widgets/inputs/search_options.dart';
import 'package:flutter/material.dart';

class SearchInput<T extends Object> extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final List<T> options;
  final int? startFiltering;
  final void Function(T selected)? onSelected;
  final String? Function(String? value)? hotValidating;
  final bool Function(String value, T option)? compareOption;
  final String Function(T option)? renderOption;

  const SearchInput({
    super.key,
    required this.controller,
    required this.labelText,
    required this.options,
    this.onSelected,
    this.hotValidating,
    this.startFiltering,
    this.compareOption,
    this.renderOption,
    this.hintText,
    this.helperText,
    this.errorText,
  });

  Iterable<T> _filteredOptions(TextEditingValue textEditingValue) {
    String value = textEditingValue.text.toLowerCase();
    if (value.length < (startFiltering ?? 1)) {
      return const [];
    }
    return options.where((item) {
      return compareOption != null
          ? compareOption!(value, item)
          : item.toString().toLowerCase().contains(value);
    });
  }

  String _renderOption(T option) {
    return renderOption != null ? renderOption!(option) : option.toString();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder:
          (context, constraints) => RawAutocomplete<T>(
            optionsBuilder: _filteredOptions,
            onSelected:
                onSelected ?? (option) => controller.text = option.toString(),
            displayStringForOption: _renderOption,
            fieldViewBuilder: (
              BuildContext context,
              TextEditingController controller,
              FocusNode focusNode,
              VoidCallback onFieldSubmitted,
            ) {
              return TextInput(
                controller: controller,
                labelText: labelText,
                hintText: hintText,
                helperText: helperText,
                errorText: errorText,
                focusNode: focusNode,
                hotValidating: hotValidating,
              );
            },
            optionsViewBuilder: (
              BuildContext context,
              AutocompleteOnSelected<T> onSelected,
              Iterable<T> options,
            ) {
              return SearchOptions<T>(
                options: options,
                onSelected: onSelected,
                renderOption: _renderOption,
                width: constraints.biggest.width,
              );
            },
          ),
    );
  }
}
