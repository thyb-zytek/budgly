import 'package:budgly/src/models/category/category.dart';

import 'package:budgly/src/services/providers/supabase/client.dart';

class CategorySupabase {
  Future<List<Category>> listByAccountId(String accountId) async {
    final response =
        await supabase
            .from('categories')
            .select('*, account:accounts(*)')
            .eq('account_id', accountId);

    return (response as List<dynamic>)
        .map((json) => Category.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Category?> create(Category category) async {
    final response =
        await supabase
            .from('categories')
            .insert(category.toJson())
            .select('*, account:accounts(*)')
            .single();
    return Category.fromJson(response);
  }

  Future<bool> update(Category category) async {
    await supabase
        .from('categories')
        .update(category.toJson())
        .eq('id', category.id!);
    return true;
  }

  Future<bool> delete(String categoryId) async {
    await supabase.from('categories').delete().eq('id', categoryId);
    return true;
  }
}
