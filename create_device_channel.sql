-- Drop existing table and policies
DROP TABLE IF EXISTS device_channel CASCADE;

-- Create device_channel table
CREATE TABLE device_channel (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    event TEXT NOT NULL,
    payload JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    device_key TEXT REFERENCES devices(device_key) ON DELETE CASCADE
);

-- Create index for better performance
CREATE INDEX idx_device_channel_device_key ON device_channel(device_key);
CREATE INDEX idx_device_channel_created_at ON device_channel(created_at);

-- Enable row level security
ALTER TABLE device_channel ENABLE ROW LEVEL SECURITY;

-- Create policy to allow insert for all (needed for realtime)
CREATE POLICY "Allow insert for all"
ON device_channel
FOR INSERT
TO public
WITH CHECK (true);

-- Create policy to allow select based on device ownership
CREATE POLICY "Allow select based on device ownership"
ON device_channel
FOR SELECT
USING (
    EXISTS (
        SELECT 1 
        FROM devices 
        WHERE devices.device_key = device_channel.device_key
    )
);

-- Create policy to allow delete for old records
CREATE POLICY "Allow delete for old records"
ON device_channel
FOR DELETE
USING (created_at < NOW() - INTERVAL '1 day');

-- Grant necessary permissions
GRANT INSERT, SELECT ON device_channel TO anon, authenticated; 