/// Index of the account-creation step (Step 2 of the onboarding sequence).
const int onboardingAccountStep = 1;

/// RL-01 §2.2 — the onboarding step to show when the flow opens.
///
/// * [savedStep] is the persisted `onboarding_step`, `null` when missing.
/// * A saved step resumes exactly there.
/// * A missing step restarts at Step 1 (index 0). Backend records that were
///   already created are adopted by the caller and never influence the step.
/// * Steps after the account step only make sense once an account exists
///   ([hasAccount]); without one, the resume is capped to the account step
///   so the user can never land on a step whose data is missing.
int resolveOnboardingStartStep({
  required int? savedStep,
  required bool hasAccount,
  required int totalSteps,
}) {
  if (savedStep == null) return 0;
  final lastReachable = hasAccount ? totalSteps - 1 : onboardingAccountStep;
  return savedStep.clamp(0, lastReachable).toInt();
}
