-- Add ip_address column to devices table
ALTER TABLE devices ADD COLUMN ip_address text;

-- Update existing records with null ip_address
UPDATE devices SET ip_address = null WHERE ip_address IS NULL; 