-- Drop existing feeding history policies
DROP POLICY IF EXISTS "Users can view their pets' feeding history" ON public.feeding_history;
DROP POLICY IF EXISTS "Users can insert feeding records for their pets" ON public.feeding_history;

-- Create updated feeding history policies
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