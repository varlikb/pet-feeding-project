-- Drop existing policies to start fresh
DROP POLICY IF EXISTS "Anyone can view devices" ON devices;
DROP POLICY IF EXISTS "Anyone can update unpaired devices" ON devices;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON devices;
DROP POLICY IF EXISTS "Enable read access for unpaired devices" ON devices;
DROP POLICY IF EXISTS "Enable update for device owners" ON devices;
DROP POLICY IF EXISTS "Enable delete for device owners" ON devices;

-- Ensure RLS is enabled
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;

-- Create basic policies
CREATE POLICY "Enable insert for authenticated users only" ON devices
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Enable read access for all authenticated users" ON devices
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Enable update for authenticated users" ON devices
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Enable delete for authenticated users" ON devices
  FOR DELETE
  TO authenticated
  USING (true); 