import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/services/image.dart';
import 'package:budgly/src/shared/widgets/avatar/avatar.dart';
import 'package:budgly/src/shared/widgets/buttons/button.dart';
import 'package:budgly/src/shared/widgets/buttons/constants.dart';
import 'package:budgly/src/shared/widgets/inputs/color_wheel.dart';
import 'package:budgly/src/shared/widgets/tabs/tab_switcher.dart';
import 'package:flutter/material.dart';

class AvatarPicker extends StatefulWidget {
  final Color color;
  final String? picture;
  final String initial;
  final void Function(Color) onChangeColor;
  final Future<String?> Function() pickImage;
  final void Function(String?) onChangePicture;
  final VoidCallback? onRemovePicture;

  const AvatarPicker({
    super.key,
    required this.color,
    required this.picture,
    required this.initial,
    required this.onChangeColor,
    required this.pickImage,
    required this.onChangePicture,
    this.onRemovePicture,
  });

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  late Color _selectedColor;
  late String? _picture;
  late bool _isLocalPicture;
  bool _hasPictureChanged = false;

  int _currentIndex = 0;

  @override
  void initState() {
    _selectedColor = widget.color;
    _picture = widget.picture;
    _isLocalPicture =
        widget.picture == null || !widget.picture!.startsWith('http');
    super.initState();
  }

  void _pickImage() {
    ImageService.pickAndCropImage(context).then((path) {
      if (path == null) return;
      setState(() {
        _picture = path;
        _hasPictureChanged = true;
        _isLocalPicture = true;
      });
    });
  }

  void _removePicture() {
    setState(() {
      _picture = null;
      _hasPictureChanged = true;
    });
    widget.onRemovePicture?.call();
  }

  void _validate() {
    if (_currentIndex == 0) {
      if (_hasPictureChanged) {
        widget.onChangePicture(_picture);
      }
    } else {
      widget.onChangeColor(_selectedColor);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 24,
      children: [
        Text(
          tr.avatarCustomization,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Avatar(
          initial: widget.initial.toUpperCase(),
          picture: _picture,
          isLocalPicture: _isLocalPicture,
          backgroundColor: _selectedColor,
          size: 108,
          showShadow: true,
          canRemove: _picture != null && widget.onRemovePicture != null,
          onRemove: _removePicture,
        ),
        TabSwitcher(
          selectedIndex: _currentIndex,
          onTabSelected: (index) => setState(() => _currentIndex = index),
          tabs: [
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                Icon(
                  Icons.image_rounded,
                  size: 17,
                  color: _currentIndex == 0
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                Text(
                  tr.picture,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: _currentIndex == 0
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: _currentIndex == 0
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                Icon(
                  Icons.palette_rounded,
                  size: 17,
                  color: _currentIndex == 1
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                Text(
                  tr.color,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: _currentIndex == 1
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: _currentIndex == 1
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SizeTransition(sizeFactor: animation, child: child),
            ),
            child: _currentIndex == 0
                ? SizedBox(
                    width: double.infinity,
                    child: BudglyButton(
                      onPressed: _pickImage,
                      leadingIcon: Icons.upload_rounded,
                      type: ButtonType.outlined,
                      text: tr.pickImage,
                    ),
                  )
                : ColorWheel(
                    key: const ValueKey('color'),
                    color: _selectedColor,
                    onChanged: (color) =>
                        setState(() => _selectedColor = color),
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Row(
            spacing: 16,
            children: [
              Expanded(
                child: BudglyButton(
                  text: tr.cancel,
                  type: ButtonType.error,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: BudglyButton(text: tr.validate, onPressed: _validate),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
