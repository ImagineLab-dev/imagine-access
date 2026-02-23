-- Add valid_until column to ticket_types
ALTER TABLE public.ticket_types 
ADD COLUMN IF NOT EXISTS valid_until TIMESTAMPTZ DEFAULT NULL;

COMMENT ON COLUMN public.ticket_types.valid_until IS 'If set, tickets of this type are only valid until this timestamp.';

-- Verify column exists
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'ticket_types' AND column_name = 'valid_until';
