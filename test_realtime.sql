-- 1. Önce realtime yapılandırmasını kontrol et
SELECT * FROM pg_publication WHERE pubname = 'supabase_realtime';

-- 2. Hangi tabloların realtime için yapılandırıldığını kontrol et
SELECT * FROM pg_publication_tables WHERE pubname = 'supabase_realtime';

-- 3. Devices tablosunun yapısını kontrol et
SELECT column_name
FROM information_schema.columns 
WHERE table_name = 'devices';

-- 4. Test cihazını devices tablosuna ekle
INSERT INTO devices (
    device_key,
    name,
    food_level,
    is_paired,
    ip_address,
    wifi_ssid,
    wifi_signal_strength,
    last_wifi_update,
    last_feeding
) VALUES (
    'TEST_DEVICE_001',
    'Test Feeder',
    100.0,
    true,
    '192.168.1.100',
    'test_wifi',
    -50,
    now(),
    now()
) ON CONFLICT (device_key) DO UPDATE 
SET 
    food_level = EXCLUDED.food_level,
    last_wifi_update = now()
RETURNING *;

-- 5. Test verisi ekleyerek realtime'ı test et
INSERT INTO device_channel (
    event,
    payload,
    device_key
) VALUES (
    'test_event',
    json_build_object(
        'message', 'test_message',
        'timestamp', now()
    ),
    'TEST_DEVICE_001'  -- Yukarıda eklediğimiz device_key'i kullan
) RETURNING *;

-- 6. Son eklenen kayıtları kontrol et
SELECT * FROM device_channel ORDER BY created_at DESC LIMIT 5;

-- 7. Realtime izinlerini kontrol et
SELECT 
    schemaname,
    tablename,
    has_table_privilege(current_user, tablename::regclass, 'INSERT') as can_insert,
    has_table_privilege(current_user, tablename::regclass, 'SELECT') as can_select
FROM pg_tables
WHERE schemaname = 'public' 
AND tablename IN ('device_channel', 'devices', 'feeding_history');

-- 8. Realtime trigger'ları kontrol et
SELECT 
    tgname as trigger_name,
    tgrelid::regclass as table_name,
    tgenabled as enabled,
    tgtype as trigger_type
FROM pg_trigger
WHERE tgrelid::regclass::text IN ('device_channel', 'devices', 'feeding_history'); 