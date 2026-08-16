import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/shared/widgets/inputs/input.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UserDetails extends StatefulWidget {
  final User user;
  final void Function(String) onChangeName;
  const UserDetails({
    super.key,
    required this.user,
    required this.onChangeName,
  });

  @override
  State<UserDetails> createState() => _UserDetailsState();
}

class _UserDetailsState extends State<UserDetails> {
  final TextEditingController _nameController = TextEditingController();
  bool _isEditingName = false;

  @override
  void initState() {
    _nameController.text = widget.user.profile?.fullName ?? '';
    super.initState();
  }

  void _displayEditName() {
    setState(() {
      _isEditingName = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16).copyWith(top: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.max,
          spacing: 32,
          children: [
            Stack(
              alignment: Alignment.centerLeft,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 8,
                  children: [
                    Text(
                      tr.name,
                      textAlign: TextAlign.start,
                      style: theme.textTheme.headlineSmall!.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    _isEditingName
                        ? Padding(
                          padding: const EdgeInsets.only(right: 96),
                          child: TextInput(
                            controller: _nameController,
                            labelText: "",
                            hotValidating:
                                (v) =>
                                    v == null || v.isEmpty
                                        ? tr.nameRequired
                                        : null,
                            textInputAction: TextInputAction.done,
                          ),
                        )
                        : Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            widget.user.profile?.fullName ?? tr.notAvailable,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                  ],
                ),
                _isEditingName
                    ? Positioned(
                      right: 0,
                      bottom: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        spacing: 4,
                        children: [
                          IconButton(
                            icon: Icon(Icons.check_circle_rounded, size: 32),
                            onPressed: () {
                              widget.onChangeName(_nameController.text);
                              setState(() {
                                _isEditingName = false;
                              });
                            },
                            color: ButtonType.primary.iconButtonColor(theme),
                            style: ButtonType.primary.iconButtonStyle(theme),
                          ),
                          IconButton(
                            icon: Icon(Icons.cancel_rounded, size: 32),
                            onPressed: () => setState(() {
                              _isEditingName = false;
                              _nameController.text =
                                  widget.user.profile?.fullName ?? '';
                            }),
                            color: ButtonType.error.iconButtonColor(theme),
                            style: ButtonType.error.iconButtonStyle(theme),
                          ),
                        ],
                      ),
                    )
                    : Positioned(
                      right: 0,
                      top: 16,
                      child: IconButton(
                        onPressed: _displayEditName,
                        icon: Icon(Icons.edit, size: 32),
                        color: ButtonType.primary.iconButtonColor(theme),
                        style: ButtonType.primary.iconButtonStyle(theme),
                      ),
                    ),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                Text(
                  tr.email,
                  textAlign: TextAlign.start,
                  style: theme.textTheme.headlineSmall!.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    widget.user.email ?? tr.notAvailable,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                Text(
                  tr.userCreatedOn,
                  textAlign: TextAlign.start,
                  style: theme.textTheme.headlineSmall!.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    widget.user.profile?.createdAt != null
                        ? DateFormat(
                          'dd/MM/yyyy',
                        ).format(widget.user.profile!.createdAt)
                        : tr.notAvailable,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
