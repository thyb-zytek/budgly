import 'dart:convert';

import 'package:budgly/src/services/categories/category_icons_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockAssetBundle extends CachingAssetBundle {
  final String json;

  _MockAssetBundle(this.json);

  @override
  Future<ByteData> load(String key) async {
    if (key == 'assets/icons/category_icons.json') {
      return ByteData.sublistView(Uint8List.fromList(utf8.encode(json)));
    }
    throw FlutterError('Asset not found: $key');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CategoryIconsService buildService(String json) {
    return CategoryIconsService(assetBundle: _MockAssetBundle(json));
  }

  test('decodes the bundled JSON catalogue into CategoryIcon list', () async {
    final service = buildService(jsonEncode([
      {
        'icon_name': 'groceries',
        'icon_code': 16,
        'icon_pack': 'BudglyIcons',
        'labels': {'en': 'Groceries', 'fr': 'Courses'},
      },
      {
        'icon_name': 'transport',
        'icon_code': '32',
        'icon_pack': 'BudglyIcons',
        'labels': {'en': 'Transport'},
      },
    ]));

    final icons = await service.getIcons();

    expect(icons, hasLength(2));
    expect(icons[0].iconName, 'groceries');
    expect(icons[0].iconCode, 16);
    expect(icons[0].labels['fr'], 'Courses');
    // icon_code provided as a string is parsed to an int.
    expect(icons[1].iconCode, 32);
  });

  test('caches the loaded icons across calls', () async {
    final service = buildService(jsonEncode([
      {
        'icon_name': 'groceries',
        'icon_code': 16,
        'icon_pack': 'BudglyIcons',
        'labels': {'en': 'Groceries'},
      },
    ]));

    final first = await service.getIcons();
    final second = await service.getIcons();

    expect(first, hasLength(1));
    expect(second, hasLength(1));
    expect(second, equals(first),
        reason: 'second call should return the same cached icons');
  });

  test('deduplicates concurrent loads (returns the same list)', () async {
    final service = buildService(jsonEncode([
      {
        'icon_name': 'groceries',
        'icon_code': 16,
        'icon_pack': 'BudglyIcons',
        'labels': {'en': 'Groceries'},
      },
    ]));

    final results = await Future.wait([service.getIcons(), service.getIcons()]);
    expect(results[0], hasLength(1));
    expect(results[1], hasLength(1));
    expect(results[1], equals(results[0]));
  });

  test('returns an empty list when the asset fails to load', () async {
    final service = buildService('not valid json {');

    final icons = await service.getIcons();

    expect(icons, isEmpty);
  });

  test('resetForTest forces a reload of the assets on the next call', () async {
    final service = CategoryIconsService(
      assetBundle: _MockAssetBundle(jsonEncode([
        {
          'icon_name': 'groceries',
          'icon_code': 16,
          'icon_pack': 'BudglyIcons',
          'labels': {'en': 'Groceries'},
        },
      ])),
    );

    final before = await service.getIcons();
    expect(before, hasLength(1));

    service.resetForTest();

    final after = await service.getIcons();
    expect(after, hasLength(1));
    expect(after[0].iconName, 'groceries');
  });
}
