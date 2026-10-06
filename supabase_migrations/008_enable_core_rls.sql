-- Core data isolation: these tables contain user-owned data and must enforce
-- their existing ownership policies at the PostgreSQL RLS layer.
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
