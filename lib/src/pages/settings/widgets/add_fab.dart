import 'package:flutter/material.dart';

class AddFab extends StatelessWidget {
  final String heroTag;
  final Function() onPressed;
  
  const AddFab({super.key, required this.heroTag, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);

    return SizedBox(
      width: 64,
      height: 64,
      child: FloatingActionButton(
        shape: const CircleBorder(),
        heroTag: 'add_account',
        elevation: 2,
        onPressed: onPressed,
        backgroundColor: theme.colorScheme.primary,
        child: Icon(
          Icons.add_rounded,
          size: 48,
          color: theme.colorScheme.onPrimary,
        ),
      ),
    );
  }
}
