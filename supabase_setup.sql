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
  device_key text not null,
  user_id uuid references auth.users not null,
  food_level double precision default 100.0 not null,
  last_feeding timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

-- Enable RLS on devices
alter table public.devices enable row level security;

-- Create policy to allow users to CRUD only their own devices
create policy "Users can manage their own devices" on public.devices
  for all using (auth.uid() = user_id);

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

-- Create feeding records table
create table public.feeding_records (
  id uuid default uuid_generate_v4() primary key,
  pet_id uuid references public.pets not null,
  amount double precision not null,
  feeding_time timestamp with time zone default now() not null,
  user_id uuid references auth.users not null,
  created_at timestamp with time zone default now() not null
);

-- Enable RLS on feeding records
alter table public.feeding_records enable row level security;

-- Create policy to allow users to CRUD only their own feeding records
create policy "Users can manage their own feeding records" on public.feeding_records
  for all using (auth.uid() = user_id);

-- Create feeding schedules table
create table public.feeding_schedules (
  id uuid default uuid_generate_v4() primary key,
  device_id uuid references public.devices not null,
  start_date date not null,
  end_date date not null,
  frequency text not null, -- 'hour' or 'day'
  start_time text not null, -- format: 'HH:MM'
  end_time text not null, -- format: 'HH:MM'
  amount double precision not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

-- Enable RLS on feeding schedules
alter table public.feeding_schedules enable row level security;

-- Create policy to allow users to CRUD only their own feeding schedules
-- This requires a join to get the user_id from the device
create policy "Users can manage their own feeding schedules" on public.feeding_schedules
  for all using (
    exists (
      select 1 from public.devices
      where devices.id = feeding_schedules.device_id
        and devices.user_id = auth.uid()
    )
  );

-- Function to handle profile creation on user signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, name)
  values (new.id, new.email, 
    coalesce(
      nullif(new.raw_user_meta_data->>'name', ''),
      split_part(new.email, '@', 1)
    )
  );
  return new;
end;
$$ language plpgsql security definer;

-- Trigger for handling new users
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user(); 