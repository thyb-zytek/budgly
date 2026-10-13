import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/errors/app_user_message.dart';
import 'package:budgly/src/core/theme/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every AppMessageKey must resolve to a real, localized sentence. A key added
/// to the enum without a translation (or mapped to the wrong one) would
/// otherwise only be noticed on the screen that shows it.
void main() {
  Future<BuildContext> contextFor(WidgetTester tester, Locale locale) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('fr')],
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return captured;
  }

  for (final locale in const [Locale('en'), Locale('fr')]) {
    testWidgets(
      'every key resolves to a non-empty message in ${locale.languageCode}',
      (tester) async {
        final context = await contextFor(tester, locale);

        for (final key in AppMessageKey.values) {
          final message = AppUserMessage.error(key).resolve(context);
          expect(message.trim(), isNotEmpty, reason: '$key');
        }
      },
    );

    testWidgets(
      'the generic error keys are distinct sentences in ${locale.languageCode}',
      (tester) async {
        final context = await contextFor(tester, locale);
        final messages = {
          for (final key in const [
            AppMessageKey.networkError,
            AppMessageKey.permissionError,
            AppMessageKey.notFoundError,
            AppMessageKey.validationError,
            AppMessageKey.unknownError,
          ])
            AppUserMessage.error(key).resolve(context),
        };

        expect(messages, hasLength(5));
      },
    );
  }

  testWidgets('a message resolves in the language of the context', (
    tester,
  ) async {
    final english = await contextFor(tester, const Locale('en'));
    final inEnglish = const AppUserMessage.success(AppMessageKey.accountSaved)
        .resolve(english);

    final french = await contextFor(tester, const Locale('fr'));
    final inFrench = const AppUserMessage.success(AppMessageKey.accountSaved)
        .resolve(french);

    expect(inEnglish, isNot(inFrench));
  });

  test('error and success constructors set the snackbar type', () {
    expect(
      const AppUserMessage.error(AppMessageKey.networkError).type,
      SnackBarType.error,
    );
    expect(
      const AppUserMessage.success(AppMessageKey.expenseSaved).type,
      SnackBarType.success,
    );
  });

  test('equality is by key and type', () {
    expect(
      const AppUserMessage.error(AppMessageKey.networkError),
      const AppUserMessage.error(AppMessageKey.networkError),
    );
    expect(
      const AppUserMessage.error(AppMessageKey.networkError),
      isNot(const AppUserMessage.success(AppMessageKey.networkError)),
    );
  });
}
