import 'package:budgly/src/models/category/category.dart';

import 'package:budgly/src/services/providers/supabase/client.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class CategorySupabase {
  final sb.SupabaseClient? _injected;
  late final sb.SupabaseClient _client = _injected ?? supabase;

  CategorySupabase({sb.SupabaseClient? client}) : _injected = client;
  Future<List<Category>> listByAccountId(String accountId) async {
    final response =
        await _client
            .from('categories')
            .select()
            .eq('account_id', accountId);

    return (response as List<dynamic>)
        .map((json) => Category.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Category?> create(Category category) async {
    final response =
        await _client
            .from('categories')
            .insert(category.toJson())
            .select()
            .single();
    return Category.fromJson(response);
  }

  Future<Category?> update(Category category) async {
    final id = category.id;
    if (id == null) return null;
    final response = await _client
        .from('categories')
        .update(category.toJson())
        .eq('id', id)
        .select()
        .maybeSingle();
    return response == null ? null : Category.fromJson(response);
  }

  Future<bool> delete(String categoryId) async {
    await _client.from('categories').delete().eq('id', categoryId);
    return true;
  }
}
