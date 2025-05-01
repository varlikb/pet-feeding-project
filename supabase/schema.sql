-- Create devices table
CREATE TABLE public.devices (
  id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  name text NOT NULL,
  device_key text NOT NULL UNIQUE,
  food_level double precision DEFAULT 1000.0 NOT NULL,
  last_feeding timestamp with time zone,
  is_paired boolean DEFAULT false NOT NULL,
  owner_id uuid REFERENCES auth.users,
  last_paired_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT positive_food_level CHECK (food_level >= 0),
  CONSTRAINT one_device_per_owner UNIQUE (owner_id)
); 