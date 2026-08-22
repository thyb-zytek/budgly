import 'package:flutter/material.dart';

Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  Color? backgroundColor,
  bool useRootNavigator = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: useRootNavigator,
    showDragHandle: true,
    backgroundColor:
        backgroundColor ?? Theme.of(context).colorScheme.surfaceContainer,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: builder,
  );
}
