-- Create tables for pet feeder app

-- Enable RLS (Row Level Security)
alter table auth.users enable row level security;

-- Create users table with profiles
create table public.profiles (
  id uuid references auth.users on delete cascade not null primary key,
  name text,
  email text,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

-- Enable RLS on profiles
alter table public.profiles enable row level security;

-- Create policy to allow users to see only their own profile
create policy "Users can view their own profile" on public.profiles
  for select using (auth.uid() = id);

-- Create policy to allow users to update only their own profile
create policy "Users can update their own profile" on public.profiles
  for update using (auth.uid() = id);

-- Create devices table
create table public.devices (
  id uuid default uuid_generate_v4() primary key,
  name text not null,
  device_key text not null unique,
  user_id uuid references auth.users not null, -- Admin who created the device
  food_level double precision default 1000.0 not null, -- in grams, default 1kg
  last_feeding timestamp with time zone,
  is_paired boolean default false not null,
  owner_id uuid references auth.users unique, -- Only one user can own a device
  last_paired_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  CONSTRAINT positive_food_level CHECK (food_level >= 0),
  CONSTRAINT one_device_per_owner UNIQUE (owner_id) -- Ensures one device per user
);

-- Enable RLS on devices
alter table public.devices enable row level security;

-- Create policy to allow admins to manage all devices
create policy "Admins can manage all devices" on public.devices
  for all using (
    exists (
      select 1 from admin_users
      where admin_users.user_id = auth.uid()
    )
  );

-- Create policy to allow users to view and pair with available devices
create policy "Users can view and pair with available devices" on public.devices
  for select using (true);

-- Create policy to allow users to update devices they own
create policy "Users can update their owned devices" on public.devices
  for update using (owner_id = auth.uid());

-- Create pets table
create table public.pets (
  id uuid default uuid_generate_v4() primary key,
  name text not null,
  weight double precision not null,
  age integer not null,
  is_female boolean not null,
  device_key text not null,
  user_id uuid references auth.users not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

-- Enable RLS on pets
alter table public.pets enable row level security;

-- Create policy to allow users to CRUD only their own pets
create policy "Users can manage their own pets" on public.pets
  for all using (auth.uid() = user_id);

-- Create a join table to connect pets and devices (many-to-many relationship)
CREATE TABLE public.pet_device_assignments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  pet_id UUID REFERENCES pets(id) ON DELETE CASCADE,
  device_id UUID REFERENCES devices(id) ON DELETE CASCADE,
  is_primary BOOLEAN DEFAULT false NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(pet_id, device_id)
);

-- Enable RLS on pet device assignments
ALTER TABLE public.pet_device_assignments ENABLE ROW LEVEL SECURITY;

-- Create policy to allow users to manage their own pet device assignments
CREATE POLICY "Users can manage their own pet device assignments" ON public.pet_device_assignments
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = pet_device_assignments.pet_id
        AND pets.user_id = auth.uid()
    )
  );

-- Create feeding records table
CREATE TABLE public.feeding_records (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  pet_id UUID REFERENCES public.pets ON DELETE CASCADE NOT NULL,
  device_id UUID REFERENCES public.devices ON DELETE CASCADE,
  amount DOUBLE PRECISION NOT NULL,
  feeding_time TIMESTAMPTZ DEFAULT now() NOT NULL,
  feeding_type TEXT NOT NULL DEFAULT 'manual',
  schedule_id UUID REFERENCES public.feeding_schedules ON DELETE SET NULL,
  user_id UUID REFERENCES auth.users NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  CONSTRAINT feeding_type_check CHECK (feeding_type IN ('manual', 'scheduled'))
);

-- Enable RLS on feeding records
ALTER TABLE public.feeding_records ENABLE ROW LEVEL SECURITY;

-- Create policy to allow users to CRUD only their own feeding records
CREATE POLICY "Users can manage their own feeding records" ON public.feeding_records
  FOR ALL USING (auth.uid() = user_id);

-- Create feeding schedules table
CREATE TABLE public.feeding_schedules (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  pet_id UUID REFERENCES public.pets ON DELETE CASCADE NOT NULL,
  device_id UUID REFERENCES public.devices ON DELETE CASCADE NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  frequency TEXT NOT NULL CHECK (frequency IN ('hour', 'day')),
  start_time TEXT NOT NULL, -- format: 'HH:MM'
  end_time TEXT NOT NULL, -- format: 'HH:MM'
  amount DOUBLE PRECISION NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  CONSTRAINT valid_date_range CHECK (end_date >= start_date)
);

-- Enable RLS on feeding schedules
ALTER TABLE public.feeding_schedules ENABLE ROW LEVEL SECURITY;

-- Create policy to allow users to manage their own feeding schedules
CREATE POLICY "Users can manage their own feeding schedules" ON public.feeding_schedules
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = feeding_schedules.pet_id
        AND pets.user_id = auth.uid()
    )
  );

-- Function to handle profile creation on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, name)
  VALUES (new.id, new.email, 
    COALESCE(
      NULLIF(new.raw_user_meta_data->>'name', ''),
      split_part(new.email, '@', 1)
    )
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for handling new users
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_feeding_records_pet_id ON feeding_records(pet_id);
CREATE INDEX IF NOT EXISTS idx_feeding_records_device_id ON feeding_records(device_id);
CREATE INDEX IF NOT EXISTS idx_feeding_records_schedule_id ON feeding_records(schedule_id);
CREATE INDEX IF NOT EXISTS idx_feeding_schedules_pet_id ON feeding_schedules(pet_id);
CREATE INDEX IF NOT EXISTS idx_feeding_schedules_device_id ON feeding_schedules(device_id);
CREATE INDEX IF NOT EXISTS idx_pet_device_pet_id ON pet_device_assignments(pet_id);
CREATE INDEX IF NOT EXISTS idx_pet_device_device_id ON pet_device_assignments(device_id); 