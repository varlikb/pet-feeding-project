-- Enable logical replication
ALTER SYSTEM SET wal_level = logical;

-- Create replication role if not exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'replication_role') THEN
    CREATE ROLE replication_role WITH REPLICATION LOGIN PASSWORD 'your_secure_password';
  END IF;
END
$$;

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO replication_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO replication_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO replication_role;

-- Enable row level security bypass for replication role
ALTER ROLE replication_role BYPASS RLS;

-- Set up replication slots
SELECT pg_create_logical_replication_slot('supabase_realtime_slot', 'pgoutput')
WHERE NOT EXISTS (
    SELECT 1 FROM pg_replication_slots WHERE slot_name = 'supabase_realtime_slot'
);

-- Configure tables for replication
ALTER TABLE public.device_channel REPLICA IDENTITY FULL;
ALTER TABLE public.devices REPLICA IDENTITY FULL;
ALTER TABLE public.feeding_history REPLICA IDENTITY FULL;

-- Verify replication settings
SELECT slot_name, plugin, slot_type, database, active
FROM pg_replication_slots;

SELECT pubname, puballtables, pubinsert, pubupdate, pubdelete 
FROM pg_publication; 