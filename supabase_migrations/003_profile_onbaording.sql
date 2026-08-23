-- Budgly: persist onboarding completion in the user profile.
-- Existing profiles are considered already onboarded so this migration
-- does not send current users back to the tutorial.

ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS onboarding_completed boolean NOT NULL DEFAULT false;

UPDATE public.user_profiles
SET onboarding_completed = true
WHERE onboarding_completed = false;

COMMENT ON COLUMN public.user_profiles.onboarding_completed IS
  'Whether the user has completed the initial Budgly onboarding tutorial.';
