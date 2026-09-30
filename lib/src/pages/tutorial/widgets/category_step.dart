import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/pages/tutorial/tutorial_provider.dart';
import 'package:budgly/src/pages/tutorial/widgets/tutorial_category_tile.dart';
import 'package:budgly/src/pages/tutorial/widgets/tutorial_step_scaffold.dart';
import 'package:budgly/src/shared/domain/widgets/categories/category_customization_sheet.dart';
import 'package:budgly/src/shared/domain/widgets/categories/category_icon_view.dart';
import 'package:budgly/src/shared/ui/mixins/pulse_hint_animation.dart';
import 'package:budgly/src/shared/ui/widgets/inputs/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' hide TextInput;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CategoryStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  const CategoryStep({super.key, required this.onNext});

  @override
  ConsumerState<CategoryStep> createState() => _CategoryStepState();
}

class _CategoryStepState extends ConsumerState<CategoryStep>
    with TickerProviderStateMixin, PulseHintAnimationMixin {
  late final FocusNode _nameFocusNode;
  late final TextEditingController _nameController;

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
    _nameController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocusNode.requestFocus();
    });
    initPulseHintAnimations();
  }

  @override
  void dispose() {
    disposePulseHintAnimations();
    _nameFocusNode.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _openCustomizationPicker(BuildContext context) async {
    cancelHint();
    final state = ref.read(tutorialProvider);
    final notifier = ref.read(tutorialProvider.notifier);
    await showCategoryCustomizationSheet(
      context,
      availableIcons: state.availableIcons,
      initialIcon: state.categoryIcon ?? AppConstants.defaultCategoryIcon,
      initialColor: state.categoryColor,
      previewBuilder: (context, icon, color) =>
          CategoryIconView(icon: icon, color: color, size: 80),
      onIconChanged: (icon) => notifier.setCategoryCustomization(icon: icon),
      onColorChanged: (color) =>
          notifier.setCategoryCustomization(color: color),
    );
    if (mounted) onHintEnabled();
  }

  Future<void> _handleValidate() async {
    if (_nameController.text.trim().isEmpty) return;
    final ok = await ref
        .read(tutorialProvider.notifier)
        .addCategory(_nameController.text);
    if (!mounted || !ok) return;
    _nameController.clear();
    HapticFeedback.selectionClick();
    _nameFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = ref.watch(tutorialProvider);
    final currentIcon = state.categoryIcon ?? AppConstants.defaultCategoryIcon;

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
                  color: state.categoryColor,
                  size: 56,
                  onTap: () => _openCustomizationPicker(context),
                  showEditBadge: true,
                ),
              ),
              Expanded(
                child: TextInput(
                  focusNode: _nameFocusNode,
                  controller: _nameController,
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
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _nameController,
            builder: (context, value, _) {
              final valid =
                  value.text.trim().isNotEmpty && !state.isAddingCategory;
              return state.isAddingCategory
                  ? FilledButton.tonalIcon(
                      onPressed: null,
                      icon: const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      label: Text(tr.add),
                    )
                  : FilledButton(
                      onPressed: valid ? _handleValidate : null,
                      child: Text(tr.add),
                    );
            },
          ),
          if (state.createdCategories.isNotEmpty)
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: state.createdCategories
                    .map(
                      (category) => TutorialCategoryTile(
                        category: category,
                        onDelete: () => ref
                            .read(tutorialProvider.notifier)
                            .removeCategory(category),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
      primaryAction: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: widget.onNext,
          child: Text(tr.tutorialNext),
        ),
      ),
    );
  }
}
