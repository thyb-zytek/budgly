import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/pages/tutorial/tutorial_provider.dart';
import 'package:budgly/src/pages/tutorial/widgets/tutorial_category_tile.dart';
import 'package:budgly/src/pages/tutorial/widgets/tutorial_step_scaffold.dart';
import 'package:budgly/src/shared/domain/widgets/categories/category_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CategoryStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  const CategoryStep({super.key, required this.onNext});

  @override
  ConsumerState<CategoryStep> createState() => _CategoryStepState();
}

class _CategoryStepState extends ConsumerState<CategoryStep> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final FocusNode _nameFocusNode;
  late final TextEditingController _nameController;
  late final TextEditingController _thresholdController;

  @override
  void initState() {
    super.initState();
    _nameFocusNode = FocusNode();
    _nameController = TextEditingController();
    _thresholdController = TextEditingController();
  }

  @override
  void dispose() {
    _nameFocusNode.dispose();
    _nameController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  Future<void> _handleAdd() async {
    if (_nameController.text.trim().isEmpty) return;
    final ok = await ref
        .read(tutorialProvider.notifier)
        .addCategory(
          _nameController.text,
          monthlyThreshold: _thresholdController.text,
        );
    if (!mounted || !ok) return;
    _nameController.clear();
    _thresholdController.clear();
    HapticFeedback.selectionClick();
    _nameFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final categoryState = ref.watch(
      tutorialProvider.select(
        (state) => (
          categoryIcon: state.categoryIcon,
          categoryColor: state.categoryColor,
          isAddingCategory: state.isAddingCategory,
          createdCategories: state.createdCategories,
          availableIcons: state.availableIcons,
        ),
      ),
    );
    final currentIcon =
        categoryState.categoryIcon ?? AppConstants.defaultCategoryIcon;

    return TutorialStepScaffold(
      title: tr.tutorialStepCategories,
      subtitle: tr.tutorialStepCategoriesDescription,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          // Reuse the shared category form (same widget as the settings tab),
          // minus its action row: the tutorial drives creation with its own
          // "add" button below.
          CategoryForm(
            formKey: _formKey,
            focusNode: _nameFocusNode,
            nameController: _nameController,
            monthlyThresholdController: _thresholdController,
            initialIcon: currentIcon,
            initialColor: categoryState.categoryColor,
            availableIcons: categoryState.availableIcons,
            onIconChanged: (icon) => ref
                .read(tutorialProvider.notifier)
                .setCategoryCustomization(icon: icon),
            onColorChanged: (color) => ref
                .read(tutorialProvider.notifier)
                .setCategoryCustomization(color: color),
            onSubmit: _handleAdd,
            withPulse: false,
            withHint: true,
            showActions: false,
            leadingHint: tr.tutorialStepCategoriesHint,
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _nameController,
            builder: (context, value, _) {
              final valid =
                  value.text.trim().isNotEmpty &&
                  !categoryState.isAddingCategory;
              return categoryState.isAddingCategory
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
                      onPressed: valid ? _handleAdd : null,
                      child: Text(tr.add),
                    );
            },
          ),
          if (categoryState.createdCategories.isNotEmpty)
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: categoryState.createdCategories
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
