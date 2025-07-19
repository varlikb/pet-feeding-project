-- First, enable replication for the tables
ALTER TABLE device_channel REPLICA IDENTITY FULL;
ALTER TABLE devices REPLICA IDENTITY FULL;
ALTER TABLE feeding_history REPLICA IDENTITY FULL;

-- Drop existing publication if exists
DROP PUBLICATION IF EXISTS supabase_realtime;

-- Create publication with specific tables and operations
CREATE PUBLICATION supabase_realtime 
FOR TABLE device_channel, devices, feeding_history
WITH (publish = 'insert,update,delete,truncate');

-- Enable realtime in Supabase
COMMENT ON PUBLICATION supabase_realtime IS 'This publication is used for realtime subscriptions';

-- Verify the publication
SELECT * FROM pg_publication WHERE pubname = 'supabase_realtime'; 