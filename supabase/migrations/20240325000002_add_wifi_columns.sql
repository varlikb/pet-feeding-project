-- Add WiFi information columns to devices table
ALTER TABLE public.devices 
  ADD COLUMN IF NOT EXISTS wifi_ssid text,
  ADD COLUMN IF NOT EXISTS wifi_signal_strength integer,
  ADD COLUMN IF NOT EXISTS last_wifi_update timestamptz DEFAULT now();

-- Update existing records
UPDATE public.devices 
SET 
  wifi_ssid = 'Unknown', 
  wifi_signal_strength = 0 
WHERE wifi_ssid IS NULL;

-- Add comments for documentation
COMMENT ON COLUMN public.devices.wifi_ssid IS 'The SSID of the WiFi network the device is connected to';
COMMENT ON COLUMN public.devices.wifi_signal_strength IS 'WiFi signal strength in dBm';
COMMENT ON COLUMN public.devices.last_wifi_update IS 'Last time the WiFi information was updated'; 