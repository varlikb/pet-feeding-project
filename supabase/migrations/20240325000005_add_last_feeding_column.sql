-- Add last_feeding column to devices table
ALTER TABLE public.devices
ADD COLUMN IF NOT EXISTS last_feeding TIMESTAMP WITH TIME ZONE DEFAULT NULL;

-- Add comment to the column
COMMENT ON COLUMN public.devices.last_feeding IS 'Timestamp of the last feeding event';

-- Drop existing device policies
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON devices;
DROP POLICY IF EXISTS "Enable read access for unpaired devices" ON devices;
DROP POLICY IF EXISTS "Enable update for device owners" ON devices;
DROP POLICY IF EXISTS "Enable delete for device owners" ON devices;

-- Create updated device policies
CREATE POLICY "Enable insert for authenticated users only" ON devices
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

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