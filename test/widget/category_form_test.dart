import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_editing_data.dart';
import 'package:budgly/src/shared/domain/view_models/category_form_view_model.dart';
import 'package:budgly/src/shared/domain/widgets/categories/category_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/builders.dart';
import '../helpers/pump_app.dart';

class _FakeCategoryFormViewModel extends ChangeNotifier
    implements CategoryFormViewModel {
  _FakeCategoryFormViewModel(this.categoryEditingData);

  @override
  final CategoryEditingData categoryEditingData;

  Category? createdCategory;
  Category? updatedCategory;
  Category? removedCategory;
  var cancelEditCalls = 0;

  @override
  Future<void> createCategory(Category category) async {
    createdCategory = category;
  }

  @override
  Future<void> updateCategory(Category category) async {
    updatedCategory = category;
  }

  @override
  Future<void> removeCategory(Category category) async {
    removedCategory = category;
  }

  @override
  void cancelEdit() {
    cancelEditCalls++;
  }
}

_FakeCategoryFormViewModel _buildViewModel({String name = ''}) {
  return _FakeCategoryFormViewModel(
    CategoryEditingData(
      nameController: TextEditingController(text: name),
      color: const Color(0xFF66BB6A),
      icon: Fixtures.categoryIcon(),
      availableIcons: [Fixtures.categoryIcon()],
    ),
  );
}

void main() {
  group('CategoryForm (creation)', () {
    testWidgets('submitting a valid name creates the category and clears nothing else', (tester) async {
      final vm = _buildViewModel(name: 'Loisirs');
      final formKey = GlobalKey<FormState>();

      await pumpApp(
        tester,
        CategoryForm(formKey: formKey, viewModel: vm),
      );

      await tester.tap(find.text('Valider'));
      await tester.pump();

      expect(vm.createdCategory, isNotNull);
      expect(vm.createdCategory!.name, 'Loisirs');
      expect(vm.updatedCategory, isNull);
    });

    testWidgets('cancelling with no category removes the in-progress draft', (tester) async {
      final vm = _buildViewModel();
      final formKey = GlobalKey<FormState>();

      await pumpApp(
        tester,
        CategoryForm(formKey: formKey, viewModel: vm),
      );

      await tester.tap(find.text('Annuler'));
      await tester.pump();

      expect(vm.removedCategory, isNotNull);
      expect(vm.cancelEditCalls, 0);
    });
  });

  group('CategoryForm (editing)', () {
    testWidgets('submitting a valid name updates the existing category', (tester) async {
      final vm = _buildViewModel(name: 'Loisirs');
      final formKey = GlobalKey<FormState>();
      final existing = Fixtures.category(id: 'cat-1', accountId: 'acc-1');

      await pumpApp(
        tester,
        CategoryForm(formKey: formKey, viewModel: vm, category: existing),
      );

      await tester.tap(find.text('Valider'));
      await tester.pump();

      expect(vm.updatedCategory, existing);
      expect(vm.createdCategory, isNull);
    });

    testWidgets('cancelling an existing category calls cancelEdit, not removeCategory', (tester) async {
      final vm = _buildViewModel();
      final formKey = GlobalKey<FormState>();
      final existing = Fixtures.category(id: 'cat-1', accountId: 'acc-1');

      await pumpApp(
        tester,
        CategoryForm(formKey: formKey, viewModel: vm, category: existing),
      );

      await tester.tap(find.text('Annuler'));
      await tester.pump();

      expect(vm.cancelEditCalls, 1);
      expect(vm.removedCategory, isNull);
    });
  });

  group('CategoryForm (compact mode)', () {
    testWidgets('renders the name field and icon without the action row', (tester) async {
      final vm = _buildViewModel(name: 'Loisirs');
      final formKey = GlobalKey<FormState>();

      await pumpApp(
        tester,
        CategoryForm(formKey: formKey, viewModel: vm, compact: true),
      );

      expect(find.text('Valider'), findsNothing);
      expect(find.text('Annuler'), findsNothing);
      expect(find.text('Loisirs'), findsOneWidget);
    });
  });
}
