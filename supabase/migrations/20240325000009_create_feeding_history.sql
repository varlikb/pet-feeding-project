-- Create feeding_history table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.feeding_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    pet_id UUID REFERENCES public.pets(id) NOT NULL,
    device_key TEXT REFERENCES public.devices(device_key) NOT NULL,
    amount NUMERIC NOT NULL,
    feeding_time TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    feeding_type TEXT NOT NULL,
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- Enable RLS
ALTER TABLE public.feeding_history ENABLE ROW LEVEL SECURITY;

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS feeding_history_pet_id_idx ON public.feeding_history(pet_id);
CREATE INDEX IF NOT EXISTS feeding_history_device_key_idx ON public.feeding_history(device_key);
CREATE INDEX IF NOT EXISTS feeding_history_user_id_idx ON public.feeding_history(user_id);

-- Add table comment
COMMENT ON TABLE public.feeding_history IS 'Records of all feeding events for pets';

-- Add column comments
COMMENT ON COLUMN public.feeding_history.id IS 'Unique identifier for the feeding record';
COMMENT ON COLUMN public.feeding_history.pet_id IS 'Reference to the pet that was fed';
COMMENT ON COLUMN public.feeding_history.device_key IS 'Reference to the device that performed the feeding';
COMMENT ON COLUMN public.feeding_history.amount IS 'Amount of food dispensed in grams';
COMMENT ON COLUMN public.feeding_history.feeding_time IS 'When the feeding occurred';
COMMENT ON COLUMN public.feeding_history.feeding_type IS 'Type of feeding (manual, scheduled, etc.)';
COMMENT ON COLUMN public.feeding_history.user_id IS 'User who initiated the feeding';
COMMENT ON COLUMN public.feeding_history.created_at IS 'When this record was created';

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their pets' feeding history" ON public.feeding_history;
DROP POLICY IF EXISTS "Users can insert feeding records for their pets" ON public.feeding_history;

-- Create policies
CREATE POLICY "Users can view their pets' feeding history" 
ON public.feeding_history FOR SELECT 
USING (
    EXISTS (
        SELECT 1 FROM public.pets
        WHERE pets.id = feeding_history.pet_id
        AND pets.user_id = auth.uid()
    )
);

CREATE POLICY "Users can insert feeding records for their pets" 
ON public.feeding_history FOR INSERT 
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.pets
        WHERE pets.id = feeding_history.pet_id
        AND pets.user_id = auth.uid()
    )
); 