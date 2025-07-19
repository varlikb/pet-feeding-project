-- Check current WAL level
SHOW wal_level;

-- Check replication slots
SELECT * FROM pg_replication_slots;

-- Check publications
SELECT * FROM pg_publication;

-- Check publication tables
SELECT * FROM pg_publication_tables;

-- Check table replication identities
SELECT 
    n.nspname as schema,
    c.relname as table,
    c.relreplident as replica_identity
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
AND c.relname IN ('device_channel', 'devices', 'feeding_history');

-- Check realtime configuration
SELECT 
    t.schemaname, 
    t.tablename, 
    EXISTS (
        SELECT 1 
        FROM pg_publication_tables pt 
        JOIN pg_publication p ON p.pubname = pt.pubname 
        WHERE pt.tablename = t.tablename
    ) as is_published
FROM pg_tables t
WHERE t.schemaname = 'public'
AND t.tablename IN ('device_channel', 'devices', 'feeding_history'); 