-- Drop existing policies
DROP POLICY IF EXISTS "Anyone can view devices" ON devices;
DROP POLICY IF EXISTS "Anyone can update unpaired devices" ON devices;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON devices;
DROP POLICY IF EXISTS "Enable read access for unpaired devices" ON devices;
DROP POLICY IF EXISTS "Enable update for device owners" ON devices;
DROP POLICY IF EXISTS "Enable delete for device owners" ON devices;

-- Create new policies
CREATE POLICY "Enable insert for authenticated users only" ON devices
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Enable read access for unpaired devices" ON devices
  FOR SELECT
  TO authenticated
  USING (
    (NOT is_paired) OR
    EXISTS (
      SELECT 1 FROM pets
      WHERE pets.device_key = devices.device_key
      AND pets.user_id = auth.uid()
    )
  );

CREATE POLICY "Enable update for device owners" ON devices
  FOR UPDATE
  TO authenticated
  USING (
    (NOT is_paired) OR
    EXISTS (
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
    (NOT is_paired) OR
    EXISTS (
      SELECT 1 FROM pets
      WHERE pets.device_key = devices.device_key
      AND pets.user_id = auth.uid()
    )
  ); 