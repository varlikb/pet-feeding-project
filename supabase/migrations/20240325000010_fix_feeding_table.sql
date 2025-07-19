-- Drop the table if it exists with any case
DROP TABLE IF EXISTS public.feeding_history;
DROP TABLE IF EXISTS public.feeding_records;
DROP TABLE IF EXISTS public."feeding_history";
DROP TABLE IF EXISTS public."feeding_records";

-- Create the table with the exact name
CREATE TABLE public.feeding_history (
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

-- Create policies with exact names
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