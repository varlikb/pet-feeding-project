-- Drop existing foreign key constraints
ALTER TABLE IF EXISTS "public"."pets" DROP CONSTRAINT IF EXISTS "pets_device_key_fkey";

-- Add device_id column
ALTER TABLE "public"."pets" ADD COLUMN IF NOT EXISTS "device_id" uuid REFERENCES "public"."devices"("id");

-- Copy data from device_key to device_id (if needed)
UPDATE "public"."pets" p
SET device_id = d.id
FROM "public"."devices" d
WHERE p.device_key = d.device_key;

-- Drop device_key column
ALTER TABLE "public"."pets" DROP COLUMN IF EXISTS "device_key";

-- Add not null constraint to device_id
ALTER TABLE "public"."pets" ALTER COLUMN "device_id" SET NOT NULL; 