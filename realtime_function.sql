-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS on_realtime_message ON device_channel;

-- Create function to handle realtime messages
create or replace function handle_realtime_message()
returns trigger as $$
begin
  if NEW.event = 'wifi_config' then
    -- Handle WiFi configuration
    update devices 
    set wifi_ssid = NEW.payload->>'ssid',
        wifi_status = 'configuring'
    where device_key = NEW.payload->>'device_key';
    
  elsif NEW.event = 'feed_now' then
    -- Handle immediate feeding command
    insert into feeding_history (device_key, amount, type)
    values (NEW.payload->>'device_key', (NEW.payload->>'amount')::float, 'manual');
    
  elsif NEW.event = 'scheduled_feed' then
    -- Handle scheduled feeding
    insert into feeding_history (device_key, amount, type)
    values (NEW.payload->>'device_key', (NEW.payload->>'amount')::float, 'scheduled');
    
  elsif NEW.event = 'heartbeat' or NEW.event = 'phx_heartbeat' then
    -- Update device status and handle both custom and Phoenix heartbeats
    update devices 
    set last_online = now(),
        status = 'online',
        connection_status = 'connected'
    where device_key = NEW.payload->>'device_key';
    
    -- Clean up old messages to prevent table bloat
    delete from device_channel
    where created_at < now() - interval '1 day';
  end if;
  
  return NEW;
end;
$$ language plpgsql security definer;

-- Create trigger for realtime message handling
create trigger on_realtime_message
  after insert on device_channel
  for each row
  execute procedure handle_realtime_message(); 