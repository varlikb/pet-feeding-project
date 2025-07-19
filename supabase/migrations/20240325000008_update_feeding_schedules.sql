-- Update feeding_schedules table to use device_key
ALTER TABLE public.feeding_schedules
  DROP COLUMN IF EXISTS device_id,
  ADD COLUMN IF NOT EXISTS device_key TEXT REFERENCES public.devices(device_key);

-- Add RLS policies for feeding_schedules
DROP POLICY IF EXISTS "Users can view their pets' feeding schedules" ON public.feeding_schedules;
DROP POLICY IF EXISTS "Users can manage their pets' feeding schedules" ON public.feeding_schedules;

CREATE POLICY "Users can view their pets' feeding schedules" 
ON public.feeding_schedules FOR SELECT 
USING (
    EXISTS (
        SELECT 1 FROM public.pets
        WHERE pets.id = feeding_schedules.pet_id
        AND pets.user_id = auth.uid()
    )
);

CREATE POLICY "Users can manage their pets' feeding schedules" 
ON public.feeding_schedules FOR ALL 
USING (
    EXISTS (
        SELECT 1 FROM public.pets
        WHERE pets.id = feeding_schedules.pet_id
        AND pets.user_id = auth.uid()
    )
); 