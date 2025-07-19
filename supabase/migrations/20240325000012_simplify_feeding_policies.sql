-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their pets' feeding history" ON public.feeding_history;
DROP POLICY IF EXISTS "Users can insert feeding records for their pets" ON public.feeding_history;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.feeding_history;
DROP POLICY IF EXISTS "Enable read access for users" ON public.feeding_history;

-- Create simple policies
CREATE POLICY "Enable all operations for authenticated users" 
ON public.feeding_history 
FOR ALL 
TO authenticated 
USING (true) 
WITH CHECK (true); 