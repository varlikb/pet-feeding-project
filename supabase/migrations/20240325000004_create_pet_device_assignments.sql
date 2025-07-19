-- Create pet_device_assignments table
CREATE TABLE public.pet_device_assignments (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    pet_id uuid NOT NULL,
    device_key text NOT NULL,
    is_primary boolean DEFAULT false,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Add foreign key relationship between pets and pet_device_assignments
ALTER TABLE public.pet_device_assignments
    ADD CONSTRAINT fk_pet_device_assignments_pet
    FOREIGN KEY (pet_id)
    REFERENCES public.pets (id)
    ON DELETE CASCADE;

-- Add foreign key relationship between devices and pet_device_assignments
ALTER TABLE public.pet_device_assignments
    ADD CONSTRAINT fk_pet_device_assignments_device
    FOREIGN KEY (device_key)
    REFERENCES public.devices (device_key)
    ON DELETE CASCADE;

-- Add indexes for better performance
CREATE INDEX idx_pet_device_assignments_pet_id
    ON public.pet_device_assignments(pet_id);

CREATE INDEX idx_pet_device_assignments_device_key
    ON public.pet_device_assignments(device_key);

-- Add RLS policies
ALTER TABLE public.pet_device_assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable read access for authenticated users"
    ON public.pet_device_assignments
    FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Enable insert for authenticated users"
    ON public.pet_device_assignments
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "Enable update for authenticated users"
    ON public.pet_device_assignments
    FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Enable delete for authenticated users"
    ON public.pet_device_assignments
    FOR DELETE
    TO authenticated
    USING (true);

-- Add test device assignment
INSERT INTO public.pet_device_assignments (pet_id, device_key, is_primary)
SELECT 
    p.id,
    'TEST_DEVICE_001',
    true
FROM public.pets p
WHERE p.name = 'Test Pet'
LIMIT 1; 