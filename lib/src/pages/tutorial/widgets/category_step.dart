import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/pages/tutorial/tutorial_provider.dart';
import 'package:budgly/src/pages/tutorial/widgets/tutorial_category_tile.dart';
import 'package:budgly/src/pages/tutorial/widgets/tutorial_step_scaffold.dart';
import 'package:budgly/src/shared/domain/widgets/categories/category_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' hide TextInput;
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

  Future<void> _handleValidate() async {
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
    final theme = Theme.of(context);
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
    final notifier = ref.read(tutorialProvider.notifier);
    final currentIcon =
        categoryState.categoryIcon ?? AppConstants.defaultCategoryIcon;

    return TutorialStepScaffold(
      title: tr.tutorialStepCategories,
      subtitle: tr.tutorialStepCategoriesDescription,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          CategoryForm(
            formKey: _formKey,
            nameController: _nameController,
            monthlyThresholdController: _thresholdController,
            initialIcon: currentIcon,
            initialColor: categoryState.categoryColor,
            availableIcons: categoryState.availableIcons,
            nameFocusNode: _nameFocusNode,
            onNameSubmitted: _handleValidate,
            onIconChanged: (icon) =>
                notifier.setCategoryCustomization(icon: icon),
            onColorChanged: (color) =>
                notifier.setCategoryCustomization(color: color),
            compact: true,
            withPulse: false,
            withHint: true,
            enabled: !categoryState.isAddingCategory,
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
                      onPressed: valid ? _handleValidate : null,
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
