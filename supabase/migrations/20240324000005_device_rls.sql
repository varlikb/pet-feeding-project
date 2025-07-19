-- Drop existing policies
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON devices;
DROP POLICY IF EXISTS "Enable read access for all authenticated users" ON devices;
DROP POLICY IF EXISTS "Enable update for device owners" ON devices;
DROP POLICY IF EXISTS "Enable delete for device owners" ON devices;

-- Create new policies
CREATE POLICY "Enable insert for anyone" ON devices
  FOR INSERT
  WITH CHECK (true);  -- Herhangi biri cihaz ekleyebilir

CREATE POLICY "Enable read access for unpaired devices and owners" ON devices
  FOR SELECT
  USING (
    (NOT is_paired)  -- Eşleşmemiş cihazlar görünür
    OR
    EXISTS (
      SELECT 1 FROM pets
      WHERE pets.device_key = devices.device_key
      AND pets.user_id = auth.uid()
    )  -- Kullanıcının kendi cihazları görünür
  );

CREATE POLICY "Enable update for unpaired devices and owners" ON devices
  FOR UPDATE
  USING (
    (NOT is_paired)  -- Eşleşmemiş cihazlar güncellenebilir
    OR
    EXISTS (
      SELECT 1 FROM pets
      WHERE pets.device_key = devices.device_key
      AND pets.user_id = auth.uid()
    )  -- Kullanıcı kendi cihazlarını güncelleyebilir
  );

CREATE POLICY "Enable delete for unpaired devices and owners" ON devices
  FOR DELETE
  USING (
    (NOT is_paired)  -- Eşleşmemiş cihazlar silinebilir
    OR
    EXISTS (
      SELECT 1 FROM pets
      WHERE pets.device_key = devices.device_key
      AND pets.user_id = auth.uid()
    )  -- Kullanıcı kendi cihazlarını silebilir
  ); 