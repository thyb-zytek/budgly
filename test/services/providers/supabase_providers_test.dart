import 'dart:convert';

import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/services/providers/supabase/accounts.dart';
import 'package:budgly/src/services/providers/supabase/categories.dart';
import 'package:budgly/src/services/providers/supabase/user_profiles.dart';
import 'package:budgly/src/services/providers/supabase/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _account = <String, dynamic>{
  'id': 'a1', 'user_id': 'u1', 'name': 'Compte courant',
  'picture': null, 'color': null,
};

const _category = <String, dynamic>{
  'id': 'c1', 'account_id': 'a1', 'name': 'Courses',
  'icon': null, 'color': null,
};

const _profile = <String, dynamic>{
  'user_id': 'u1', 'email': 'test@budgly.app', 'full_name': 'Test',
  'theme_mode': 'system', 'currency': 'EUR',
  'amount_decimal_places': 2, 'language': 'fr',
  'onboarding_completed': false, 'accounts': [],
};

Response _json(BaseRequest request, Object body, [int status = 200]) => Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
      request: request,
    );

SupabaseClient _client() => SupabaseClient(
      'http://127.0.0.1:0',
      'test-key',
      httpClient: MockClient((request) async {
        final path = request.url.path;
        final method = request.method;
        switch (true) {
          case final _ when path.endsWith('/accounts') && method == 'GET':
            return _json(request, [_account]);
          case final _ when path.endsWith('/accounts'):
            return _json(request, _account);
          case final _ when path.endsWith('/categories') && method == 'GET':
            return _json(request, [_category]);
          case final _ when path.endsWith('/categories'):
            return _json(request, _category);
          case final _ when path.endsWith('/user_profiles'):
            return _json(request, _profile);
          default:
            return _json(request, {'error': 'not found'}, 404);
        }
      }),
    );

void main() {
  late SupabaseClient client;

  setUp(() {
    client = _client();
  });

  test('AccountSupabase maps list/create/update/delete through Supabase', () async {
    final provider = AccountSupabase(client: client);
    const account = Account(id: 'a1', userId: 'u1', name: 'Compte courant');

    expect((await provider.listByUserId('u1')).single.id, 'a1');
    expect((await provider.create(account))?.name, 'Compte courant');
    expect((await provider.update(account))?.id, 'a1');
    expect(await provider.update(const Account(name: 'Compte courant')), isNull);
    expect(await provider.delete('a1'), isTrue);
  });

  test('CategorySupabase maps list/create/update/delete through Supabase', () async {
    final provider = CategorySupabase(client: client);
    final category = Category(id: 'c1', accountId: 'a1', name: 'Courses');

    expect((await provider.listByAccountId('a1')).single.id, 'c1');
    expect((await provider.create(category))?.id, 'c1');
    expect((await provider.update(category))?.name, 'Courses');
    expect(await provider.update(Category(accountId: 'a1')), isNull);
    expect(await provider.delete('c1'), isTrue);
  });

  test('StorageSupabase rejects a missing local file before network access', () async {
    final provider = StorageSupabase(client: client);
    expect(
      () => provider.uploadFile(
        bucketId: 'avatars',
        filePath: '/definitely/missing/avatar.png',
        userId: 'u1',
      ),
      throwsException,
    );
  });

  test('UserProfileSupabase reads, creates and updates a profile', () async {
    final provider = UserProfileSupabase(client: client);

    final profile = await provider.getProfile('u1');
    expect(profile?.id, 'u1');
    expect((await provider.createProfile('u1', {
      'user_id': 'u1',
      'email': 'test@budgly.app',
      'full_name': 'Test',
      'accounts': [],
    })).fullName, 'Test');
    expect(await provider.updateProfile('u1', {'full_name': 'Updated'}), isTrue);
  });
}
