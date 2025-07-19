-- Test mesajı ekle
INSERT INTO device_channel (
    event,
    payload,
    device_key
) VALUES (
    'feed_now',
    jsonb_build_object(
        'amount', 50.0,
        'timestamp', now(),
        'test', true
    ),
    'TEST_DEVICE_001'
) RETURNING *; 