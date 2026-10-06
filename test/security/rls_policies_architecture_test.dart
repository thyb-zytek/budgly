import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _readMigration(String name) =>
    File('supabase_migrations/$name').readAsStringSync();

void main() {
  late String initial;
  late String storage;
  late String rlsEnablement;

  setUpAll(() {
    initial = _readMigration('001_initial.sql');
    storage = _readMigration('006_storage_rls.sql');
    rlsEnablement = _readMigration('008_enable_core_rls.sql');
  });

  group('Core RLS migration contracts', () {
    test('enables RLS on every core user-owned table', () {
      for (final table in ['user_profiles', 'accounts', 'categories']) {
        expect(
          rlsEnablement,
          contains('ALTER TABLE public.$table ENABLE ROW LEVEL SECURITY;'),
          reason: '$table must have RLS enabled',
        );
      }
    });

    test('defines ownership policies for every core table', () {
      expect(
        initial,
        contains('CREATE POLICY "Users can insert their own profile"'),
      );
      expect(
        initial,
        contains('CREATE POLICY "Users can view their own profile"'),
      );
      expect(
        initial,
        contains('CREATE POLICY "Users can update their own profile"'),
      );

      expect(
        initial,
        contains('CREATE POLICY "Users can view their own accounts"'),
      );
      expect(
        initial,
        contains('CREATE POLICY "Users can insert their own accounts"'),
      );
      expect(
        initial,
        contains('CREATE POLICY "Users can update their own accounts"'),
      );
      expect(
        initial,
        contains('CREATE POLICY "Users can delete their own accounts"'),
      );

      expect(
        initial,
        contains(
          'CREATE POLICY "Users can view categories from their accounts"',
        ),
      );
      expect(
        initial,
        contains(
          'CREATE POLICY "Users can insert categories in their accounts"',
        ),
      );
      expect(
        initial,
        contains(
          'CREATE POLICY "Users can update categories in their accounts"',
        ),
      );
      expect(
        initial,
        contains(
          'CREATE POLICY "Users can delete categories from their accounts"',
        ),
      );
    });

    test('policies use the Firebase UID from the Supabase JWT', () {
      final jwtOwnership = RegExp(
        r'\(auth\.jwt\(\)\s*->>\s*\x27sub\x27\)::text',
      );
      expect(jwtOwnership.allMatches(initial).length, greaterThanOrEqualTo(10));
    });

    test('category policies derive ownership through the parent account', () {
      final categoryPolicies = RegExp(
        r'CREATE POLICY "Users can (?:view|insert|update|delete) categories[^\n]*.*?\n.*?EXISTS \(\s*\n\s*SELECT 1 FROM accounts',
        dotAll: true,
      );
      expect(categoryPolicies.allMatches(initial).length, 4);
    });
  });

  group('Storage RLS contracts', () {
    test(
      'account pictures require an authenticated JWT and matching UID path',
      () {
        expect(storage, contains("auth.jwt() is not null"));
        expect(
          storage,
          contains("(auth.jwt() ->> 'sub') = split_part(name, '/', 1)"),
        );
      },
    );

    test('config files are public-read only', () {
      expect(storage, contains('create policy "Public can read config files"'));
      expect(
        storage,
        contains("for select\nto public\nusing (bucket_id = 'config-files')"),
      );
      expect(storage, isNot(contains('create policy "Public Insert"')));
      expect(storage, isNot(contains('create policy "Public Update"')));
      expect(storage, isNot(contains('create policy "Public Delete"')));
    });
  });
}
