CREATE TABLE IF NOT EXISTS public.user_profiles (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id TEXT UNIQUE NOT NULL,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT,
  avatar_url TEXT,
  color TEXT NOT NULL,
  theme_mode TEXT DEFAULT 'system' CHECK (theme_mode IN ('light', 'dark', 'system')),
  currency TEXT DEFAULT 'EUR',
  language TEXT DEFAULT 'fr-FR',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create accounts table
CREATE TABLE IF NOT EXISTS public.accounts (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id TEXT REFERENCES user_profiles(user_id) ON DELETE CASCADE NOT NULL,
  full_name TEXT NOT NULL,
  picture TEXT,
  color TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create categories table
CREATE TABLE IF NOT EXISTS public.categories (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  account_id UUID REFERENCES public.accounts(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  color TEXT NOT NULL,
  icon TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX idx_accounts_user_id ON public.accounts(user_id);
CREATE INDEX idx_categories_account_id ON public.categories(account_id);

-- Set up Row Level Security (RLS) policies
-- User Profile RLS
CREATE POLICY "Users can insert their own profile" 
  ON user_profiles FOR INSERT 
  WITH CHECK (user_id = (auth.jwt() ->> 'user_id')::text);

CREATE POLICY "Users can view their own profile" 
  ON user_profiles FOR SELECT 
  USING (user_id = (auth.jwt() ->> 'user_id')::text);

CREATE POLICY "Users can update their own profile" 
  ON user_profiles FOR UPDATE 
  USING (user_id = (auth.jwt() ->> 'user_id')::text);

-- Accounts RLS
CREATE POLICY "Users can view their own accounts" 
  ON accounts FOR SELECT 
  USING (user_id = (auth.jwt() ->> 'user_id')::text);

CREATE POLICY "Users can insert their own accounts" 
  ON accounts FOR INSERT 
  WITH CHECK (user_id = (auth.jwt() ->> 'user_id')::text);

CREATE POLICY "Users can update their own accounts" 
  ON accounts FOR UPDATE 
  USING (user_id = (auth.jwt() ->> 'user_id')::text);

CREATE POLICY "Users can delete their own accounts" 
  ON accounts FOR DELETE 
  USING (user_id = (auth.jwt() ->> 'user_id')::text);

-- Categories RLS
CREATE POLICY "Users can view categories from their accounts" 
  ON categories FOR SELECT 
  USING (EXISTS (
    SELECT 1 FROM accounts 
    WHERE accounts.id = categories.account_id 
    AND accounts.user_id = (auth.jwt() ->> 'user_id')::text
  ));

CREATE POLICY "Users can insert categories in their accounts" 
  ON categories FOR INSERT 
  WITH CHECK (EXISTS (
    SELECT 1 FROM accounts 
    WHERE accounts.id = categories.account_id 
    AND accounts.user_id = (auth.jwt() ->> 'user_id')::text
  ));

CREATE POLICY "Users can update categories in their accounts" 
  ON categories FOR UPDATE 
  USING (EXISTS (
    SELECT 1 FROM accounts 
    WHERE accounts.id = categories.account_id 
    AND accounts.user_id = (auth.jwt() ->> 'user_id')::text
  ));

CREATE POLICY "Users can delete categories from their accounts" 
  ON categories FOR DELETE 
  USING (EXISTS (
    SELECT 1 FROM accounts 
    WHERE accounts.id = categories.account_id 
    AND accounts.user_id = (auth.jwt() ->> 'user_id')::text
  ));

-- Mettre à jour la fonction de création de profil
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_profiles (user_id, email, full_name, color)
  VALUES (
    NEW.uid,
    NEW.email, 
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    lpad(to_hex(floor(random() * 16777215)::int), 6, '0')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a trigger to handle new user signups
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Fonction utilitaire pour mettre à jour le champ updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;   
END;
$$ LANGUAGE plpgsql;

-- Ajouter les déclencheurs pour les mises à jour
CREATE TRIGGER update_user_profile_updated_at
BEFORE UPDATE ON public.user_profiles
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_accounts_updated_at
BEFORE UPDATE ON public.accounts
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_categories_updated_at
BEFORE UPDATE ON public.categories
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Enable Row Level Security
ALTER TABLE IF EXISTS public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.categories ENABLE ROW LEVEL SECURITY;
