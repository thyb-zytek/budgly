import 'package:app/l10n/app_localizations.dart';
import 'package:app/src/shared/widgets/buttons/constants.dart';
import 'package:app/src/shared/widgets/buttons/icon_button.dart';
import 'package:flutter/material.dart';

class DropDown<T> extends StatefulWidget {
  final T? initialValue;
  final List<T> options;
  final void Function(T option) onSelect;
  final Widget Function(T option) optionBuilder;
  final bool dense;

  const DropDown({
    super.key,
    required this.onSelect,
    required this.options,
    required this.optionBuilder,
    this.initialValue,
    this.dense = false,
  });

  @override
  State<DropDown<T>> createState() => _DropDownState<T>();
}

class _DropDownState<T extends dynamic> extends State<DropDown<T>>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  bool _isDropdownOpen = false;
  late T? _selectedOption;

  @override
  void initState() {
    _selectedOption = widget.options.isNotEmpty ? widget.options.first : null;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 100),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInQuad,
      reverseCurve: Curves.fastEaseInToSlowEaseOut,
    );
    super.initState();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _openDropdown() {
    if (!_isDropdownOpen) {
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
      setState(() => _isDropdownOpen = true);
      _animationController.forward();
    } else {
      _closeDropdown();
    }
  }

  void _closeDropdown() {
    _animationController.reverse().then((_) {
      setState(() {
        _isDropdownOpen = false;
      });
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder:
          (context) => Positioned(
            right: 0,
            top: 0,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.centerRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(-24, 16),
              child: LayoutBuilder(
                builder:
                    (context, constraints) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Material(
                          elevation: 8,
                          animationDuration: const Duration(milliseconds: 200),
                          borderRadius: BorderRadius.circular(5),
                          type: MaterialType.card,
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          child: SizeTransition(
                            sizeFactor: _expandAnimation,
                            axisAlignment: 1.0,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: 10,
                                maxWidth: constraints.biggest.width,
                                maxHeight: constraints.biggest.height * 0.5,
                              ),
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(8, 8, 24, 8),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  spacing: 4,
                                  children:
                                      widget.options
                                          .map(
                                            (option) => InkWell(
                                              onTap: () => _onOptionTap(option),
                                              child: widget.optionBuilder(
                                                option,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
              ),
            ),
          ),
    );
  }

  void _onOptionTap(T option) {
    setState(() {
      _selectedOption = option;
    });
    widget.onSelect(option);
    _closeDropdown();
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations? tr = AppLocalizations.of(context);

    return CompositedTransformTarget(
      link: _layerLink,
      child: TapRegion(
        onTapOutside: (_) {
          if (_isDropdownOpen) _closeDropdown();
        },
        onTapInside: (_) {
          if (!_isDropdownOpen) {
            _openDropdown();
          } else {
            _closeDropdown();
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _selectedOption != null
                ? Padding(
                    padding:
                        widget.dense
                            ? const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            )
                            : const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                    child: DefaultTextStyle(
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      child: widget.optionBuilder(_selectedOption!),
                    ),
                  )
                : Padding(
                  padding:
                      widget.dense
                          ? const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          )
                          : const EdgeInsets.all(
                            8,
                          ).add(EdgeInsets.only(top: 4)),
                  child: Text(
                    tr!.noOptionsAvailable,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium!.apply(heightFactor: 1.2),
                  ),
                ),
            widget.options.length > 1
                ? BudglyIconButton(
                  icon: Icons.arrow_drop_down_rounded,
                  type: ButtonType.iconDefault,
                  onPressed: () {
                    if (!_isDropdownOpen) {
                      _openDropdown();
                    } else {
                      _closeDropdown();
                    }
                  },
                )
                : Container(),
          ],
        ),
      ),
    );
  }
}
