import 'package:budgly/src/models/category/category.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  test('serializes monthly threshold', () {
    final category = Category(id: '1', accountId: 'a', monthlyThreshold: 350);
    expect(category.toJson()['monthly_threshold'], 350);
    expect(Category.fromJson({'id':'1','account_id':'a','monthly_threshold':350}).monthlyThreshold, 350);
  });
  test('copyWith can clear monthly threshold', () {
    final category = Category(accountId: 'a', monthlyThreshold: 10);
    expect(category.copyWith(clearMonthlyThreshold: true).monthlyThreshold, isNull);
  });
}
