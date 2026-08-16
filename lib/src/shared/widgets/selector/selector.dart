import 'package:flutter/material.dart';

class Selector<T> extends StatefulWidget {
  final List<T> items;
  final T? selectedItem;
  final ValueChanged<T> onSelect;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Color? backgroundColor;
  final double? maxHeight;

  const Selector({
    super.key,
    required this.items,
    this.selectedItem,
    required this.onSelect,
    required this.itemBuilder,
    this.backgroundColor,
    this.maxHeight
  });

  @override
  State<Selector<T>> createState() => _SelectorState<T>();
}

class _SelectorState<T> extends State<Selector<T>> {
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentItem = (widget.selectedItem != null && widget.items.contains(widget.selectedItem))
        ? widget.selectedItem!
        : widget.items.first;

    final colorScheme = Theme.of(context).colorScheme;

    return PopupMenuButton<T>(
      initialValue: currentItem,
      onOpened: () => setState(() => _isOpen = true),
      onCanceled: () => setState(() => _isOpen = false),
      tooltip: '',
      color: colorScheme.surface,
      position: PopupMenuPosition.under,
      constraints: widget.maxHeight != null
          ? BoxConstraints(maxHeight: widget.maxHeight!)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
      menuPadding: const EdgeInsets.all(8),
      offset: Offset(MediaQuery.of(context).size.width, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        decoration: BoxDecoration(
          color: widget.backgroundColor ?? colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: widget.itemBuilder(context, currentItem),
              ),
            ),
            AnimatedRotation(
              turns: _isOpen ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: const Icon(Icons.arrow_drop_down_rounded, size: 32),
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        for (final item in widget.items)
          PopupMenuItem<T>(
            value: item,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: widget.itemBuilder(context, item),
          ),
      ],
      onSelected: (item) {
        setState(() => _isOpen = false);
        widget.onSelect(item);
      },
    );
  }
}