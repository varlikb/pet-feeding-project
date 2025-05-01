-- First, drop the dependent policies
DROP POLICY IF EXISTS "Users can manage their own feeding schedules" ON feeding_schedules;
DROP POLICY IF EXISTS "Users can manage pet-device assignments via devices" ON pet_device_assignments;

-- Create new policies using owner_id instead of user_id
CREATE POLICY "Users can manage their own feeding schedules" ON feeding_schedules
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM devices
      WHERE devices.id = feeding_schedules.device_id
      AND devices.owner_id = auth.uid()
    )
  );

CREATE POLICY "Users can manage pet-device assignments" ON pet_device_assignments
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM devices
      WHERE devices.id = pet_device_assignments.device_id
      AND devices.owner_id = auth.uid()
    )
  );

-- Now we can safely remove user_id and update defaults
ALTER TABLE public.devices
  DROP COLUMN IF EXISTS user_id,
  ALTER COLUMN food_level SET DEFAULT 1000.0,
  ALTER COLUMN is_paired SET DEFAULT false,
  ALTER COLUMN created_at SET DEFAULT now(),
  ALTER COLUMN updated_at SET DEFAULT now();

-- Add trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE OR REPLACE TRIGGER update_devices_updated_at
    BEFORE UPDATE ON devices
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column(); 