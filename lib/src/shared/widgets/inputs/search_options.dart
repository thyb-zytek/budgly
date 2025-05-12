import 'package:flutter/material.dart';

class SearchOptions<T extends Object> extends StatelessWidget {
  final double width;
  final Iterable<T> options;
  final void Function(T selected) onSelected;
  final String Function(T option) renderOption;

  const SearchOptions({
    super.key,
    required this.width,
    required this.options,
    required this.onSelected,
    required this.renderOption,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(top: 2, left: 8),
      child: Align(
        alignment: Alignment.topLeft,
        child: Material(
          color: theme.colorScheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          elevation: 10,
          child: SizedBox(
            width: width - 16,
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: options.length,
              itemBuilder: (BuildContext context, int index) {
                final T option = options.elementAt(index);
                return ListTile(
                  title: Text(
                    renderOption(option),
                    style: theme.textTheme.bodyLarge,
                  ),
                  onTap: () => onSelected(option),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
