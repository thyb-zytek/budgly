import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/shared/ui/widgets/inputs/input.dart';
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

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _displayEditName() {
    setState(() {
      _isEditingName = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _buildUserDetailsView(context);
  }

  Widget _buildUserDetailsView(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.all(
          BudglySpacing.lg,
        ).copyWith(top: BudglySpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: 32,
          children: [
            _buildNameSection(context, theme),
            _buildInfoSection(
              context,
              theme,
              title: AppLocalizations.of(context)!.email,
              value:
                  widget.user.email ??
                  AppLocalizations.of(context)!.notAvailable,
            ),
            _buildInfoSection(
              context,
              theme,
              title: AppLocalizations.of(context)!.userCreatedOn,
              value: widget.user.profile?.createdAt != null
                  ? DateFormat(
                      'dd/MM/yyyy',
                    ).format(widget.user.profile!.createdAt)
                  : AppLocalizations.of(context)!.notAvailable,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameSection(BuildContext context, ThemeData theme) {
    final tr = AppLocalizations.of(context)!;
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
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
                      labelText: '',
                      hotValidating: (v) =>
                          v == null || v.isEmpty ? tr.nameRequired : null,
                      textInputAction: TextInputAction.done,
                    ),
                  )
                : Padding(
                    padding: EdgeInsets.only(left: BudglySpacing.sm),
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
                      icon: const Icon(Icons.check_circle_rounded, size: 32),
                      onPressed: () {
                        widget.onChangeName(_nameController.text);
                        setState(() => _isEditingName = false);
                      },
                      color: theme.colorScheme.primary,
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel_rounded, size: 32),
                      onPressed: () => setState(() {
                        _isEditingName = false;
                        _nameController.text =
                            widget.user.profile?.fullName ?? '';
                      }),
                      color: theme.colorScheme.error,
                    ),
                  ],
                ),
              )
            : Positioned(
                right: 0,
                top: 16,
                child: IconButton(
                  onPressed: _displayEditName,
                  icon: const Icon(Icons.edit, size: 32),
                  color: theme.colorScheme.primary,
                ),
              ),
      ],
    );
  }

  Widget _buildInfoSection(
    BuildContext context,
    ThemeData theme, {
    required String title,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text(
          title,
          textAlign: TextAlign.start,
          style: theme.textTheme.headlineSmall!.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        Padding(
          padding: EdgeInsets.only(left: BudglySpacing.sm),
          child: Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
