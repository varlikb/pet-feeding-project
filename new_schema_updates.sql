-- Add pet_id column to existing feeding_schedules table if not already there
ALTER TABLE feeding_schedules 
ADD COLUMN IF NOT EXISTS pet_id UUID;

-- Add appropriate indexes for the new column
CREATE INDEX IF NOT EXISTS idx_feeding_schedules_pet_id ON feeding_schedules(pet_id);

-- Try to drop constraint first if it exists (to avoid errors)
DO $$
BEGIN
    -- Attempt to drop constraint if it exists
    BEGIN
        ALTER TABLE feeding_schedules DROP CONSTRAINT fk_pet_feeding_schedules;
    EXCEPTION
        WHEN undefined_object THEN
        -- Constraint doesn't exist, do nothing
    END;
END $$;

-- Add foreign key constraint for the new column
ALTER TABLE feeding_schedules 
ADD CONSTRAINT fk_pet_feeding_schedules 
FOREIGN KEY (pet_id) REFERENCES pets(id) ON DELETE CASCADE;

-- Add RLS policy for feeding_schedules based on pet_id
DROP POLICY IF EXISTS "Users can manage their pet feeding schedules" ON public.feeding_schedules;
CREATE POLICY "Users can manage their pet feeding schedules" ON public.feeding_schedules
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = feeding_schedules.pet_id
        AND pets.user_id = auth.uid()
    )
  );

-- Create a join table to connect pets and devices (many-to-many relationship)
CREATE TABLE IF NOT EXISTS pet_device_assignments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  pet_id UUID REFERENCES pets(id) ON DELETE CASCADE,
  device_id UUID REFERENCES devices(id) ON DELETE CASCADE,
  is_primary BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(pet_id, device_id)
);

-- Enable RLS on pet_device_assignments
ALTER TABLE pet_device_assignments ENABLE ROW LEVEL SECURITY;

-- Create policy to allow users to manage pet-device assignments based on pet ownership
CREATE POLICY "Users can manage pet-device assignments via pets" ON public.pet_device_assignments
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = pet_device_assignments.pet_id
        AND pets.user_id = auth.uid()
    )
  );

-- Create policy to allow users to manage pet-device assignments based on device ownership
CREATE POLICY "Users can manage pet-device assignments via devices" ON public.pet_device_assignments
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.devices
      WHERE devices.id = pet_device_assignments.device_id
        AND devices.user_id = auth.uid()
    )
  );

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_pet_device_pet_id ON pet_device_assignments(pet_id);
CREATE INDEX IF NOT EXISTS idx_pet_device_device_id ON pet_device_assignments(device_id);

-- Try to drop constraint first if it exists (to avoid errors)
DO $$
BEGIN
    -- Attempt to drop constraint if it exists
    BEGIN
        ALTER TABLE feeding_records DROP CONSTRAINT fk_pet_feeding_records;
    EXCEPTION
        WHEN undefined_object THEN
        -- Constraint doesn't exist, do nothing
    END;
END $$;

-- Make sure feeding_records foreign key is properly set up
ALTER TABLE feeding_records 
ADD CONSTRAINT fk_pet_feeding_records 
FOREIGN KEY (pet_id) REFERENCES pets(id) ON DELETE CASCADE; 