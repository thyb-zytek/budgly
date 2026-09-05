import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/bottom_sheet.dart';
import 'package:budgly/src/shared/ui/widgets/customization_picker.dart';
import 'package:budgly/src/shared/ui/widgets/layout/avatar.dart';
import 'package:budgly/src/shared/ui/widgets/layout/color_wheel.dart';
import 'package:budgly/src/shared/ui/widgets/tabs/tab.dart';
import 'package:flutter/material.dart';

Future<bool> showAvatarCustomizationSheet(
  BuildContext context, {
  required String initial,
  required String? initialPicture,
  required Color initialColor,
  required Future<String?> Function() pickImage,
  required ValueChanged<String?> onPictureChanged,
  required ValueChanged<Color> onColorChanged,
}) {
  final theme = Theme.of(context);
  final tr = AppLocalizations.of(context)!;

  var selectedPicture = initialPicture;
  var selectedColor = initialColor;

  bool isLocalPicture(String? picture) =>
      picture != null && !picture.startsWith('http');

  return showAppBottomSheet(
    context,
    backgroundColor: theme.colorScheme.surface,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: CustomizationPicker(
                title: tr.avatarCustomization,
                previewWidget: Avatar(
                  initial: initial,
                  picture: selectedPicture,
                  isLocalPicture: isLocalPicture(selectedPicture),
                  backgroundColor: selectedColor,
                  size: 88,
                  canRemove: selectedPicture != null,
                  onRemove: () => setModalState(() {
                    selectedPicture = null;
                    onPictureChanged(null);
                  }),
                ),
                tabTitles: [
                  TabTitle(
                      icon: Icons.photo_library_rounded, title: tr.picture),
                  TabTitle(icon: Icons.palette_rounded, title: tr.color),
                ],
                tabs: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(),
                      onPressed: () => pickImage().then((path) {
                        if (path == null) return;
                        setModalState(() {
                          selectedPicture = path;
                          onPictureChanged(path);
                        });
                      }),
                      iconAlignment: IconAlignment.start,
                      icon: const Icon(
                        Icons.upload_rounded,
                        
                      ),
                      label: Text(
                        tr.pickImage,
                        
                      ),
                    ),
                  ),
                  ColorWheel(
                    key: const ValueKey('avatar_color_wheel'),
                    color: selectedColor,
                    onChanged: (color) => setModalState(() {
                      selectedColor = color;
                      onColorChanged(color);
                    }),
                  ),
                ],
                onValidate: () => Navigator.pop(sheetContext, true),
                onCancel: () => Navigator.pop(sheetContext, false),
              ),
            ),
          );
        },
      );
    },
  ).then((result) => result ?? false);
}
