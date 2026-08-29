import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/snackbar.dart';
import 'package:flutter/widgets.dart';

enum AppMessageKey {
  networkError,
  permissionError,
  notFoundError,
  validationError,
  unknownError,

  accountSaved,
  accountDeleted,
  categorySaved,
  categoryDeleted,
  expenseSaved,
  expenseDeleted,
  budgetSaved,
  pictureUpdateFailed,
  nameChanged,
  passwordChanged,
  passwordChangeFailed,
  profileRefreshed,
  refreshProfileFailed,
}

class AppUserMessage {
  const AppUserMessage(this.key, this.type);

  final AppMessageKey key;
  final SnackBarType type;

  const AppUserMessage.error(AppMessageKey key) : this(key, SnackBarType.error);
  const AppUserMessage.success(AppMessageKey key) : this(key, SnackBarType.success);

  String resolve(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    return switch (key) {
      AppMessageKey.networkError => tr.errorNetwork,
      AppMessageKey.permissionError => tr.errorPermission,
      AppMessageKey.notFoundError => tr.errorNotFound,
      AppMessageKey.validationError => tr.errorValidation,
      AppMessageKey.unknownError => tr.errorUnknown,
      AppMessageKey.accountSaved => tr.accountSaved,
      AppMessageKey.accountDeleted => tr.accountDeleted,
      AppMessageKey.categorySaved => tr.categorySaved,
      AppMessageKey.categoryDeleted => tr.categoryDeleted,
      AppMessageKey.expenseSaved => tr.expenseSaved,
      AppMessageKey.expenseDeleted => tr.expenseDeleted,
      AppMessageKey.budgetSaved => tr.budgetSaved,
      AppMessageKey.pictureUpdateFailed => tr.pictureUpdateFailed,
      AppMessageKey.nameChanged => tr.nameChangedSuccessfully,
      AppMessageKey.passwordChanged => tr.passwordChangedSuccessfully,
      AppMessageKey.passwordChangeFailed => tr.passwordChangeFailed,
      AppMessageKey.profileRefreshed => tr.profileRefreshed,
      AppMessageKey.refreshProfileFailed => tr.refreshProfileFailed,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is AppUserMessage && other.key == key && other.type == type;

  @override
  int get hashCode => Object.hash(key, type);
}

AppMessageKey classifyError(Object error) {
  final description = error.toString().toLowerCase();

  if (_containsAny(description, const [
    'socketexception',
    'timeoutexception',
    'network',
    'connection',
    'failed host lookup',
  ])) {
    return AppMessageKey.networkError;
  }

  if (_containsAny(description, const [
    'permission',
    'unauthorized',
    'forbidden',
    'row-level security',
    'rls',
    '401',
    '403',
  ])) {
    return AppMessageKey.permissionError;
  }

  if (_containsAny(description, const [
    'not-found',
    'notfound',
    'not found',
    '404',
  ])) {
    return AppMessageKey.notFoundError;
  }

  return AppMessageKey.unknownError;
}

bool _containsAny(String haystack, List<String> needles) =>
    needles.any(haystack.contains);
