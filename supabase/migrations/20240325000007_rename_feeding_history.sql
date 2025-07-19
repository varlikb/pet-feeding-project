-- Rename feeding_records table to feeding_history if it exists
ALTER TABLE IF EXISTS public.feeding_records 
RENAME TO feeding_history;

-- Update the policies to use the new table name
DROP POLICY IF EXISTS "Users can view their pets' feeding history" ON public.feeding_history;
DROP POLICY IF EXISTS "Users can insert feeding records for their pets" ON public.feeding_history;

-- Recreate the policies with the correct table name
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