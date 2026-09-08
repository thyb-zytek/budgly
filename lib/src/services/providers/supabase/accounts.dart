import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/models/account/account.dart';

import 'package:budgly/src/services/providers/supabase/client.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class AccountSupabase {
  final sb.SupabaseClient? _injected;
  late final sb.SupabaseClient _client = _injected ?? supabase;

  AccountSupabase({sb.SupabaseClient? client}) : _injected = client;
  Future<List<Account>> listByUserId(String userId) async {
    final response =
        await _client.from('accounts').select().eq('user_id', userId).timeout(AppConstants.networkTimeout);

    return (response as List<dynamic>)
        .map((json) => Account.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Account?> create(Account account) async {
    final response =
        await _client
            .from('accounts')
            .insert(account.toJson())
            .select()
            .single();
    return Account.fromJson(response);
  }

  Future<Account?> update(Account account) async {
    final id = account.id;
    if (id == null) return null;
    final response =
        await _client
            .from('accounts')
            .update(account.toJson())
            .eq('id', id)
            .select()
            .maybeSingle();
    return response == null ? null : Account.fromJson(response);
  }

  Future<bool> delete(String accountId) async {
    await _client.from('accounts').delete().eq('id', accountId);
    return true;
  }
}
