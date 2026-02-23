-- Add color column to ticket_types
ALTER TABLE public.ticket_types 
ADD COLUMN IF NOT EXISTS color TEXT DEFAULT '#4F46E5';

COMMENT ON COLUMN public.ticket_types.color IS 'Color hex code for ticket type UI representation.';

-- Verify column exists
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'ticket_types' AND column_name = 'color';
