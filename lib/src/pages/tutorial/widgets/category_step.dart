import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/pages/tutorial/view_model.dart';
import 'package:budgly/src/pages/tutorial/widgets/tutorial_step_scaffold.dart';
import 'package:budgly/src/pages/tutorial/widgets/tutorial_category_tile.dart';
import 'package:budgly/src/shared/domain/widgets/categories/category_customization_sheet.dart';
import 'package:budgly/src/shared/domain/widgets/categories/category_icon_view.dart';
import 'package:budgly/src/shared/ui/mixins/pulse_hint_animation.dart';
import 'package:budgly/src/shared/ui/widgets/inputs/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' hide TextInput;

class CategoryStep extends StatefulWidget {
  final TutorialViewModel viewModel;
  final VoidCallback onNext;

  const CategoryStep({
    super.key,
    required this.viewModel,
    required this.onNext,
  });

  @override
  State<CategoryStep> createState() => _CategoryStepState();
}

class _CategoryStepState extends State<CategoryStep>
    with TickerProviderStateMixin, PulseHintAnimationMixin {
  late final FocusNode _nameFocusNode;

  @override
  bool get withPulse => false;
  @override
  bool get withHint => true;
  @override
  bool get hintEnabled => true;

  @override
  void initState() {
    super.initState();
    _nameFocusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocusNode.requestFocus();
    });

    initPulseHintAnimations();
  }

  @override
  void dispose() {
    disposePulseHintAnimations();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _openCustomizationPicker(BuildContext context) {
    cancelHint();
    final vm = widget.viewModel;

    showCategoryCustomizationSheet(
      context,
      availableIcons: vm.availableIcons,
      initialIcon: vm.categoryIcon ?? AppConstants.defaultCategoryIcon,
      initialColor: vm.categoryColor,
      previewBuilder: (context, icon, color) => CategoryIconView(
        icon: icon,
        color: color,
        size: 80,
      ),
      onIconChanged: vm.setCategoryIcon,
      onColorChanged: vm.setCategoryColor,
    ).then((_) {
      if (!mounted) return;
      onHintEnabled();
    });
  }

  Future<void> _handleValidate() async {
    if (!widget.viewModel.isCategoryValid) return;
    final ok = await widget.viewModel.addCategory();
    if (!mounted) return;
    if (ok) {
      HapticFeedback.selectionClick();
      _nameFocusNode.requestFocus();
    }
  }

  Future<void> _handleNext() async {
    if (mounted) widget.onNext();
  }


  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final vm = widget.viewModel;
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final currentIcon = vm.categoryIcon ?? AppConstants.defaultCategoryIcon;

        return TutorialStepScaffold(
          title: tr.tutorialStepCategories,
          subtitle: tr.tutorialStepCategoriesDescription,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              Row(
                spacing: 16,
                children: [
                  PulseHint(
                    pulseAnimation: pulseAnimation,
                    hintAnimation: hintAnimation,
                    child: CategoryIconView(
                      icon: currentIcon,
                      color: vm.categoryColor,
                      size: 56,
                      onTap: () => _openCustomizationPicker(context),
                      showEditBadge: true,
                    ),
                  ),
                  Expanded(
                    child: TextInput(
                      focusNode: _nameFocusNode,
                      controller: vm.categoryNameController,
                      labelText: tr.categoryName,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleValidate(),
                    ),
                  ),
                ],
              ),
              Text(
                tr.tapToCustomize,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              ListenableBuilder(
                listenable: vm.categoryNameController,
                builder: (context, _) {
                  final isValid = vm.isCategoryValid && !vm.isAddingCategory;
                  return vm.isAddingCategory
                      ? FilledButton.tonalIcon(
                          onPressed: isValid ? _handleValidate : null,
                          icon: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          label: Text(tr.add),
                        )
                      : FilledButton(
                                                    onPressed: isValid ? _handleValidate : null,
                          child: Text(tr.add),
                        );
                },
              ),
              if (vm.createdCategories.isNotEmpty)
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: vm.createdCategories
                        .map((category) => TutorialCategoryTile(
                              category: category,
                              onDelete: () => vm.removeCategory(category),
                            ))
                        .toList(),
                  ),
                ),
            ],
          ),
          primaryAction: ListenableBuilder(
            listenable: vm.categoryNameController,
            builder: (context, _) {
              final canProceed = vm.hasCategories;

              return SizedBox(
                width: double.infinity,
                child: FilledButton(
                                    onPressed: canProceed ? _handleNext : null,
                  child: Text(
                    tr.tutorialNext,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

