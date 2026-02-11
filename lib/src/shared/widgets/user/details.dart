import 'package:app/src/shared/widgets/inputs/input.dart';
import 'package:flutter/material.dart';
import 'package:app/src/models/user/user.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:app/src/shared/widgets/buttons/icon_button.dart';
import 'package:app/src/shared/widgets/buttons/constants.dart';

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
      color: theme.colorScheme.surfaceContainer,
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
                            style: theme.textTheme.bodyMedium,
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
                          BudglyIconButton(
                            icon: Icons.check_circle_rounded,
                            type: ButtonType.success,
                            onPressed: () {
                              widget.onChangeName(_nameController.text);
                              setState(() {
                                _isEditingName = false;
                              });
                            },
                            smallIcon: true,
                          ),
                          BudglyIconButton(
                            icon: Icons.cancel_rounded,
                            type: ButtonType.error,
                            onPressed:
                                () => setState(() {
                                  _isEditingName = false;
                                  _nameController.text =
                                      widget.user.profile?.fullName ?? '';
                                }),
                            smallIcon: true,
                          ),
                        ],
                      ),
                    )
                    : Positioned(
                      right: 0,
                      top: 0,
                      child: BudglyIconButton(
                        onPressed: _displayEditName,
                        icon: Icons.edit,
                        type: ButtonType.primary,
                        smallIcon: true,
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
                    style: theme.textTheme.bodyMedium,
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
                    style: theme.textTheme.bodyMedium,
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
