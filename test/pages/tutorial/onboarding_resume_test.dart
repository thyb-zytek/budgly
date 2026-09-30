import 'package:budgly/src/pages/tutorial/onboarding_resume.dart';
import 'package:flutter_test/flutter_test.dart';

/// RL-01 §2.2 — direct, branch-by-branch coverage of the pure onboarding
/// resume rule. `tutorial_provider_test.dart` exercises this indirectly
/// through the provider, but leaves the clamp-without-an-account branch
/// untested.
void main() {
  test('no saved step restarts at Step 1 (index 0), account or not', () {
    expect(
      resolveOnboardingStartStep(
        savedStep: null,
        hasAccount: false,
        totalSteps: 5,
      ),
      0,
    );
    expect(
      resolveOnboardingStartStep(
        savedStep: null,
        hasAccount: true,
        totalSteps: 5,
      ),
      0,
    );
  });

  test('a saved step resumes exactly there once an account exists', () {
    expect(
      resolveOnboardingStartStep(savedStep: 3, hasAccount: true, totalSteps: 5),
      3,
    );
  });

  test('a saved step past the last step is clamped to the last step', () {
    expect(
      resolveOnboardingStartStep(
        savedStep: 99,
        hasAccount: true,
        totalSteps: 5,
      ),
      4,
    );
  });

  test(
    'a saved step is capped to the account-creation step when there is no '
    'account yet, so the user never lands on a step whose data is missing',
    () {
      expect(
        resolveOnboardingStartStep(
          savedStep: 4,
          hasAccount: false,
          totalSteps: 5,
        ),
        onboardingAccountStep,
      );
      expect(
        resolveOnboardingStartStep(
          savedStep: 1,
          hasAccount: false,
          totalSteps: 5,
        ),
        onboardingAccountStep,
      );
    },
  );

  test(
    'a saved step before the account step is preserved even without an account',
    () {
      expect(
        resolveOnboardingStartStep(
          savedStep: 0,
          hasAccount: false,
          totalSteps: 5,
        ),
        0,
      );
    },
  );
}
