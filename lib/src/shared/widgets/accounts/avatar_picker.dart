import 'package:app/l10n/app_localizations.dart';
import 'package:app/src/services/image.dart';
import 'package:app/src/shared/widgets/accounts/avatar.dart';
import 'package:app/src/shared/widgets/buttons/button.dart';
import 'package:app/src/shared/widgets/buttons/constants.dart';
import 'package:app/src/shared/widgets/tabs/tab_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

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

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AlertDialog(
      titlePadding: const EdgeInsets.all(0),
      contentPadding: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TabSwitcher(
            selectedIndex: _currentIndex,
            onTabSelected: (index) => setState(() => _currentIndex = index),
            tabs: [Text(tr.picture), Text(tr.color)],
          ),
          Stack(
            alignment: Alignment.topRight,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 32,
                  horizontal: 16,
                ).copyWith(bottom: 16),
                child: Avatar(
                  initial: widget.initial.toUpperCase(),
                  picture: _picture,
                  isLocalPicture: _isLocalPicture,
                  backgroundColor: _selectedColor,
                  size: 120,
                ),
              ),
              if (_picture != null && widget.onRemovePicture != null)
                Positioned(
                  top: 24,
                  right: 8,
                  child: Material(
                    color: Colors.transparent,
                    elevation: 1,
                    shape: const CircleBorder(),
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.onSurface.withAlpha(50),
                            blurRadius: 48,
                            offset: const Offset(2, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, size: 28),
                        color: theme.colorScheme.onError,
                        padding: EdgeInsets.zero, 
                        onPressed: _removePicture,
                      ),
                    ),
                  ),
                )
            ],
          ),  
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child:
                _currentIndex == 0
                    ? Column(
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              width: 2,
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          onPressed: _pickImage,
                          child: Text(
                            tr.pickImage,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                      ],
                    )
                    : HueRingPicker(
                      pickerColor: _selectedColor,
                      onColorChanged:
                          (color) => setState(() => _selectedColor = color),
                      enableAlpha: false,
                      displayThumbColor: false,
                      pickerAreaBorderRadius: BorderRadius.circular(10),
                    ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              mainAxisSize: MainAxisSize.max,
              children: [
                BudglyButton(
                  text: tr.cancel,
                  type: ButtonType.error,
                  dense: true,
                  onPressed: () => Navigator.pop(context),
                ),
                BudglyButton(
                  text: tr.validate,
                  type: ButtonType.success,
                  dense: true,
                  onPressed: () {
                    if (_currentIndex == 0) {
                      if (_hasPictureChanged) {
                        widget.onChangePicture(_picture);
                      }
                    } else {
                      widget.onChangeColor(_selectedColor);
                    }
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
