-- Replace the legacy boolean rounding preference with a generic amount precision.
-- 2 is the default and preserves the previous non-rounded behaviour.
ALTER TABLE user_profiles
ADD COLUMN IF NOT EXISTS amount_decimal_places INTEGER NOT NULL DEFAULT 2;

-- Preserve existing users' setting from the previous migration.
UPDATE user_profiles
SET amount_decimal_places = CASE
  WHEN COALESCE(round_up_expenses, FALSE) THEN 0
  ELSE 2
END
WHERE round_up_expenses IS NOT NULL;

ALTER TABLE user_profiles
DROP CONSTRAINT IF EXISTS user_profiles_amount_decimal_places_check;

ALTER TABLE user_profiles
ADD CONSTRAINT user_profiles_amount_decimal_places_check
CHECK (amount_decimal_places BETWEEN 0 AND 2);

ALTER TABLE user_profiles
DROP COLUMN IF EXISTS round_up_expenses;
