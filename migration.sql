-- First, drop existing policies on devices table
DROP POLICY IF EXISTS "Users can manage their own devices" ON public.devices;
DROP POLICY IF EXISTS "Admins can manage all devices" ON public.devices;
DROP POLICY IF EXISTS "Users can view and pair with available devices" ON public.devices;
DROP POLICY IF EXISTS "Users can update their owned devices" ON public.devices;

-- Add new columns if they don't exist
ALTER TABLE public.devices 
  ADD COLUMN IF NOT EXISTS is_paired boolean DEFAULT false NOT NULL,
  ADD COLUMN IF NOT EXISTS owner_id uuid REFERENCES auth.users,
  ADD COLUMN IF NOT EXISTS last_paired_at timestamp with time zone;

-- Make device_key unique if it's not already
ALTER TABLE public.devices 
  DROP CONSTRAINT IF EXISTS devices_device_key_key;
ALTER TABLE public.devices 
  ADD CONSTRAINT devices_device_key_key UNIQUE (device_key);

-- Add constraint to ensure one device per owner
ALTER TABLE public.devices 
  DROP CONSTRAINT IF EXISTS one_device_per_owner;
ALTER TABLE public.devices 
  ADD CONSTRAINT one_device_per_owner UNIQUE (owner_id);

-- Create new policies

-- Allow admins to manage all devices
CREATE POLICY "Admins can manage all devices" ON public.devices
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM admin_users
      WHERE admin_users.user_id = auth.uid()
    )
  );

-- Allow users to view available devices
CREATE POLICY "Users can view and pair with available devices" ON public.devices
  FOR SELECT USING (true);

-- Allow users to update devices they own
CREATE POLICY "Users can update their owned devices" ON public.devices
  FOR UPDATE USING (owner_id = auth.uid());

-- Update existing records to ensure consistency
UPDATE public.devices
SET is_paired = CASE 
    WHEN owner_id IS NOT NULL THEN true
    ELSE false
  END
WHERE is_paired IS NULL; 