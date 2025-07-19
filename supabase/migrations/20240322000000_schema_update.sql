-- Drop existing tables if they exist
DROP TABLE IF EXISTS public.feeding_schedules CASCADE;
DROP TABLE IF EXISTS public.feeding_history CASCADE;
DROP TABLE IF EXISTS public.pets CASCADE;
DROP TABLE IF EXISTS public.devices CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create profiles table
CREATE TABLE public.profiles (
    id UUID REFERENCES auth.users PRIMARY KEY,
    name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Create profiles policies
CREATE POLICY "Users can view their own profile" 
ON public.profiles FOR SELECT 
USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile" 
ON public.profiles FOR UPDATE 
USING (auth.uid() = id);

-- Create devices table
CREATE TABLE public.devices (
    device_key TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    food_level NUMERIC DEFAULT 1000,
    is_paired BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS for devices table
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;

-- Policy for inserting devices (allow authenticated users)
CREATE POLICY "Enable insert for authenticated users only" ON devices
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Policy for viewing devices (allow authenticated users to see unpaired devices or their own paired devices)
CREATE POLICY "Enable read access for unpaired devices" ON devices
  FOR SELECT
  TO authenticated
  USING (
    (NOT is_paired) OR  -- Allow viewing unpaired devices
    EXISTS (           -- Or devices paired with user's pets
      SELECT 1 FROM pets
      WHERE pets.device_key = devices.device_key
      AND pets.user_id = auth.uid()
    )
  );

-- Policy for updating devices (allow authenticated users to update unpaired devices or their own paired devices)
CREATE POLICY "Enable update for device owners" ON devices
  FOR UPDATE
  TO authenticated
  USING (
    (NOT is_paired) OR  -- Allow updating unpaired devices
    EXISTS (           -- Or devices paired with user's pets
      SELECT 1 FROM pets
      WHERE pets.device_key = devices.device_key
      AND pets.user_id = auth.uid()
    )
  )
  WITH CHECK (true);

-- Policy for deleting devices (allow authenticated users to delete unpaired devices or their own paired devices)
CREATE POLICY "Enable delete for device owners" ON devices
  FOR DELETE
  TO authenticated
  USING (
    (NOT is_paired) OR  -- Allow deleting unpaired devices
    EXISTS (           -- Or devices paired with user's pets
      SELECT 1 FROM pets
      WHERE pets.device_key = devices.device_key
      AND pets.user_id = auth.uid()
    )
  );

-- Create pets table
CREATE TABLE public.pets (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT NOT NULL,
    weight NUMERIC NOT NULL,
    age INTEGER NOT NULL,
    is_female BOOLEAN DEFAULT true,
    device_key TEXT REFERENCES public.devices(device_key),
    user_id UUID REFERENCES auth.users NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on pets
ALTER TABLE public.pets ENABLE ROW LEVEL SECURITY;

-- Create pets policies
CREATE POLICY "Users can view their own pets" 
ON public.pets FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own pets" 
ON public.pets FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own pets" 
ON public.pets FOR UPDATE 
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own pets" 
ON public.pets FOR DELETE 
USING (auth.uid() = user_id);

-- Create feeding_history table
CREATE TABLE public.feeding_history (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    pet_id UUID REFERENCES public.pets(id) ON DELETE CASCADE,
    device_key TEXT REFERENCES public.devices(device_key),
    amount NUMERIC NOT NULL,
    feeding_time TIMESTAMPTZ DEFAULT NOW(),
    feeding_type TEXT DEFAULT 'manual',
    user_id UUID REFERENCES auth.users NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on feeding_history
ALTER TABLE public.feeding_history ENABLE ROW LEVEL SECURITY;

-- Create feeding_history policies
CREATE POLICY "Users can view their pets' feeding history" 
ON public.feeding_history FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert feeding records for their pets" 
ON public.feeding_history FOR INSERT 
WITH CHECK (auth.uid() = user_id);

-- Create feeding_schedules table
CREATE TABLE public.feeding_schedules (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    pet_id UUID REFERENCES public.pets(id) ON DELETE CASCADE,
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    frequency TEXT NOT NULL,
    start_time TEXT NOT NULL,
    amount NUMERIC NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on feeding_schedules
ALTER TABLE public.feeding_schedules ENABLE ROW LEVEL SECURITY;

-- Create feeding_schedules policies
CREATE POLICY "Users can view their pets' feeding schedules" 
ON public.feeding_schedules FOR SELECT 
USING (
    EXISTS (
        SELECT 1 FROM public.pets
        WHERE pets.id = feeding_schedules.pet_id
        AND pets.user_id = auth.uid()
    )
);

CREATE POLICY "Users can manage their pets' feeding schedules" 
ON public.feeding_schedules FOR ALL 
USING (
    EXISTS (
        SELECT 1 FROM public.pets
        WHERE pets.id = feeding_schedules.pet_id
        AND pets.user_id = auth.uid()
    )
);

-- Create function to handle new user creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, name)
    VALUES (new.id, new.raw_user_meta_data->>'name');
    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for new user creation
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_pets_user_id ON public.pets(user_id);
CREATE INDEX IF NOT EXISTS idx_pets_device_key ON public.pets(device_key);
CREATE INDEX IF NOT EXISTS idx_feeding_history_pet_id ON public.feeding_history(pet_id);
CREATE INDEX IF NOT EXISTS idx_feeding_history_user_id ON public.feeding_history(user_id);
CREATE INDEX IF NOT EXISTS idx_feeding_schedules_pet_id ON public.feeding_schedules(pet_id); 