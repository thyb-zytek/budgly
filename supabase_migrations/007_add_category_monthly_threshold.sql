-- Optional monthly spending threshold per category.
ALTER TABLE public.categories
  ADD COLUMN IF NOT EXISTS monthly_threshold NUMERIC NULL;

ALTER TABLE public.categories
  ADD CONSTRAINT categories_monthly_threshold_positive
  CHECK (monthly_threshold IS NULL OR monthly_threshold > 0);
