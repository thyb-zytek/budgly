import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/shared/widgets/buttons/constants.dart';
import 'package:budgly/src/shared/widgets/buttons/icon_button.dart';
import 'package:flutter/material.dart';

class DropDown<T> extends StatefulWidget {
  final T? initialValue;
  final List<T> options;
  final void Function(T option) onSelect;
  final Widget Function(T option, bool isSelected) optionBuilder;
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

class _DropDownState<T> extends State<DropDown<T>>
    with SingleTickerProviderStateMixin {
  static const _animationDuration = Duration(milliseconds: 180);
  static const _reverseAnimationDuration = Duration(milliseconds: 120);
  static const _menuMaxHeight = 400.0;

  final LayerLink _layerLink = LayerLink();

  late final AnimationController _animationController;
  late final Animation<double> _expandAnimation;

  OverlayEntry? _overlayEntry;

  T? _selectedOption;

  bool _isDropdownOpen = false;

  int _overlayGeneration = 0;

  @override
  void initState() {
    super.initState();

    _selectedOption = _resolveInitialValue();

    _animationController = AnimationController(
      vsync: this,
      duration: _animationDuration,
      reverseDuration: _reverseAnimationDuration,
    );

    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  T? _resolveInitialValue() {
    if (widget.options.isEmpty) {
      return null;
    }

    if (widget.initialValue != null &&
        widget.options.contains(widget.initialValue)) {
      return widget.initialValue;
    }

    return widget.options.first;
  }

  @override
  void didUpdateWidget(DropDown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    final optionsChanged = oldWidget.options != widget.options;
    final initialValueChanged = oldWidget.initialValue != widget.initialValue;

    if (optionsChanged || initialValueChanged) {
      final newSelection = _resolveInitialValue();

      if (newSelection != _selectedOption) {
        setState(() {
          _selectedOption = newSelection;
        });
      }
    }
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;

    _animationController.dispose();

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Dropdown state
  // ---------------------------------------------------------------------------

  void _toggleDropdown() {
    if (widget.options.length <= 1) {
      return;
    }

    if (_isDropdownOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    if (_isDropdownOpen || widget.options.length <= 1) {
      return;
    }

    _overlayGeneration++;

    _overlayEntry = _createOverlayEntry();

    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);

    setState(() {
      _isDropdownOpen = true;
    });

    _animationController.forward(from: 0);
  }

  void _closeDropdown({bool immediate = false}) {
    if (!_isDropdownOpen && _overlayEntry == null) {
      return;
    }

    final currentGeneration = _overlayGeneration;

    if (immediate) {
      _removeOverlay();
      return;
    }

    _animationController.reverse().whenComplete(() {
      if (currentGeneration != _overlayGeneration) {
        return;
      }

      if (!mounted) {
        _removeOverlay();
        return;
      }

      _removeOverlay();

      if (_isDropdownOpen) {
        setState(() {
          _isDropdownOpen = false;
        });
      }
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;

    _isDropdownOpen = false;

    if (mounted) {
      setState(() {});
    }
  }

  // ---------------------------------------------------------------------------
  // Selection
  // ---------------------------------------------------------------------------

  void _onOptionTap(T option) {
    if (option == _selectedOption) {
      _closeDropdown();
      return;
    }

    setState(() {
      _selectedOption = option;
    });

    widget.onSelect(option);

    _closeDropdown();
  }

  // ---------------------------------------------------------------------------
  // Overlay
  // ---------------------------------------------------------------------------

  OverlayEntry _createOverlayEntry() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return OverlayEntry(
      builder: (overlayContext) {
        return Stack(
          children: [
            // -----------------------------------------------------------------
            // Outside tap barrier
            // -----------------------------------------------------------------
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeDropdown,
                child: const SizedBox.expand(),
              ),
            ),

            // -----------------------------------------------------------------
            // Dropdown menu
            // -----------------------------------------------------------------
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 6),
              child: Material(
                type: MaterialType.transparency,
                child: FadeTransition(
                  opacity: _expandAnimation,
                  child: Transform.translate(
                    offset: Offset(-16, -24),
                    child: SizeTransition(
                      sizeFactor: _expandAnimation,
                      alignment: Alignment.topRight,
                      child: Container(
                        constraints: const BoxConstraints(
                          maxHeight: _menuMaxHeight,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: SingleChildScrollView(
                            padding: EdgeInsets.zero,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: widget.options.map((option) {
                                return _DropdownOption<T>(
                                  option: option,
                                  selected: option == _selectedOption,
                                  dense: widget.dense,
                                  optionBuilder: widget.optionBuilder,
                                  onTap: () => _onOptionTap(option),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Main widget
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasOptions = widget.options.isNotEmpty;
    final canOpen = widget.options.length > 1;

    return Semantics(
      button: canOpen,
      expanded: _isDropdownOpen,
      enabled: canOpen,
      label: tr?.noOptionsAvailable,
      child: CompositedTransformTarget(
        link: _layerLink,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: canOpen ? _toggleDropdown : null,
            child: Padding(
              padding: widget.dense
                  ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
                  : const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: hasOptions
                        ? DefaultTextStyle(
                            style: theme.textTheme.bodyMedium!.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                            child: widget.optionBuilder(
                              _selectedOption as T,
                              false,
                            ),
                          )
                        : Text(
                            tr?.noOptionsAvailable ?? '',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                  if (canOpen) ...[
                    const SizedBox(width: 2),
                    AnimatedRotation(
                      turns: _isDropdownOpen ? 0.5 : 0,
                      duration: _animationDuration,
                      curve: Curves.easeOutCubic,
                      child: BudglyIconButton(
                        smallIcon: widget.dense,
                        icon: Icons.arrow_drop_down_rounded,
                        type: ButtonType.iconDefault,
                        onPressed: _toggleDropdown,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Dropdown option
// =============================================================================

class _DropdownOption<T> extends StatelessWidget {
  final T option;
  final bool selected;
  final bool dense;
  final Widget Function(T option, bool isSelected) optionBuilder;
  final VoidCallback onTap;

  const _DropdownOption({
    required this.option,
    required this.selected,
    required this.dense,
    required this.optionBuilder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 44),
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 8 : 10,
            vertical: dense ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primaryContainer.withAlpha(125)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DefaultTextStyle(
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
                child: optionBuilder(option, selected),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
