import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/analytics/analytics_service_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'expenses_service_provider.g.dart';

@Riverpod(keepAlive: true)
Raw<ExpensesService> expensesService(Ref ref) =>
    ExpensesService(analytics: ref.watch(analyticsServiceProvider));
