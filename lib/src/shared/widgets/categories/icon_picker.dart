import 'package:app/l10n/app_localizations.dart';
import 'package:app/src/models/category/category_icon.dart' as cim;
import 'package:app/src/shared/widgets/buttons/button.dart';
import 'package:app/src/shared/widgets/buttons/constants.dart';
import 'package:app/src/shared/widgets/categories/icon.dart';
import 'package:app/src/shared/widgets/inputs/input.dart';
import 'package:app/src/shared/widgets/inputs/search_input.dart';
import 'package:app/src/shared/widgets/tabs/tab_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_iconpicker/flutter_iconpicker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class IconPicker extends StatefulWidget {
  final Color color;
  final cim.CategoryIcon? icon;
  final List<cim.CategoryIcon> availableIcons;
  final ValueChanged<Color> onChangeColor;
  final ValueChanged<cim.CategoryIcon> onChangeIcon;

  const IconPicker({
    super.key,
    required this.color,
    required this.icon,
    required this.availableIcons,
    required this.onChangeColor,
    required this.onChangeIcon,
  });

  @override
  State<IconPicker> createState() => _IconPickerState();
}

class _IconPickerState extends State<IconPicker> {
  late Color _selectedColor;
  late cim.CategoryIcon? _icon;
  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  List<cim.CategoryIcon> _filteredIcons = [];

  @override
  void initState() {
    _selectedColor = widget.color;
    _icon = widget.icon;
    _filteredIcons = widget.availableIcons;
    _searchController.addListener(
      () => _filterIcons(AppLocalizations.of(context)!.localeName),
    );
    super.initState();
  }

  void _filterIcons(String locale) {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredIcons =
          widget.availableIcons.where((cim.CategoryIcon icon) {
            final label = icon.labels[locale] ?? icon.iconName;
            return label.toLowerCase().contains(query);
          }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(
      () => _filterIcons(AppLocalizations.of(context)!.localeName),
    );
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      titlePadding: const EdgeInsets.all(0),
      contentPadding: const EdgeInsets.all(8).copyWith(top: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TabSwitcher(
            selectedIndex: _currentIndex,
            onTabSelected: (index) => setState(() => _currentIndex = index),
            tabs: [Text(tr.icon), Text(tr.color)],
          ),
          Column(
            spacing: 8,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 16),
                child: CategoryIcon(
                  icon: _icon!,
                  size: 52,
                  color: _selectedColor,
                  onChangeColor:
                      (color) => setState(() => _selectedColor = color),
                  onChangeIcon: (icon) => setState(() => _icon = icon),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.40,
                  width: MediaQuery.of(context).size.width * 0.75,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child:
                        _currentIndex == 0
                            ? Column(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  // child: SearchInput<cim.CategoryIcon>(
                                  //   controller: _searchController,
                                  //   labelText: tr.searchIcon,
                                  //   options: widget.availableIcons,
                                  //   renderOption:
                                  //       (icon) => icon.labels[tr.localeName]!,
                                  //   compareOption: (value, option) {
                                  //     final label =
                                  //         option.labels[tr.localeName];
                                  //     return label?.toLowerCase().contains(
                                  //           value.toLowerCase(),
                                  //         ) ??
                                  //         false;
                                  //   },
                                  //   onSelected: (icon) {
                                  //     _searchController.text =
                                  //         icon.labels[tr.localeName] ??
                                  //         icon.iconName;
                                  //     _filterIcons(tr.localeName);
                                  //     setState(() => _icon = icon);
                                  //     widget.onChangeIcon(icon);
                                  //   },
                                  // ),
                                  child: TextInput(
                                    controller: _searchController,
                                    labelText: tr.searchIcon,
                                    onChange:
                                        (v) => _filterIcons(tr.localeName),
                                    onFieldSubmitted: (v) {
                                      _filterIcons(tr.localeName);
                                      widget.onChangeIcon(_filteredIcons.first);
                                    },
                                  ),
                                ),
                                Expanded(
                                  child: GridView.builder(
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 5,
                                          crossAxisSpacing: 8,
                                          mainAxisSpacing: 8,
                                          childAspectRatio: 1,
                                        ),
                                    itemCount: _filteredIcons.length,
                                    itemBuilder: (context, index) {
                                      final icon = _filteredIcons[index];

                                      return InkWell(
                                        borderRadius: BorderRadius.circular(10),
                                        onTap: () {
                                          setState(() => _icon = icon);
                                          widget.onChangeIcon(icon);
                                        },
                                        child: Icon(
                                          IconPickerIcon(
                                            name: icon.iconName,
                                            data: icon.iconData,
                                            pack: icon.iconPack,
                                          ).data,
                                          size: 40,
                                          color:
                                              _icon?.iconName == icon.iconName
                                                  ? colorScheme.primary
                                                  : colorScheme.onSurface,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            )
                            : HueRingPicker(
                              pickerColor: _selectedColor,
                              onColorChanged:
                                  (color) =>
                                      setState(() => _selectedColor = color),
                              enableAlpha: false,
                              displayThumbColor: false,
                              pickerAreaBorderRadius: BorderRadius.circular(10),
                            ),
                  ),
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
                        widget.onChangeIcon(_icon!);
                        widget.onChangeColor(_selectedColor);
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
