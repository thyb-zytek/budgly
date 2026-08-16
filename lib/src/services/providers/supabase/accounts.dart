import 'package:budgly/src/models/account/account.dart';

import 'package:budgly/src/services/providers/supabase/client.dart';

class AccountSupabase {
  Future<List<Account>> listByUserId(String userId) async {
    final response =
        await supabase.from('accounts').select().eq('user_id', userId);

    return (response as List<dynamic>)
        .map((json) => Account.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Account?> create(Account account) async {
    final response =
        await supabase
            .from('accounts')
            .insert(account.toJson())
            .select()
            .single();
    return Account.fromJson(response);
  }

  Future<Account?> update(Account account) async {
    final response =
        await supabase
            .from('accounts')
            .update(account.toJson())
            .eq('id', account.id!)
            .select()
            .single();
    return Account.fromJson(response);
  }

  Future<bool> delete(String accountId) async {
    await supabase.from('accounts').delete().eq('id', accountId);
    return true;
  }
}
