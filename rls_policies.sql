-- Create device_channel table if not exists
create table if not exists device_channel (
  id uuid default uuid_generate_v4() primary key,
  event text not null,
  payload jsonb not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- RLS policy for device_channel
create policy "Enable insert for all users"
on device_channel
for insert
to public
with check (true);

-- RLS policies for devices table
create policy "Enable read access for all users"
on devices
for select
to public
using (true);

create policy "Enable update for all devices"
on devices
for update
to public
using (true); 