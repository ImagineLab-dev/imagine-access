-- ==========================================
-- FIX: AGREGAR COLUMNA SCANNED_AT A TICKETS
-- ==========================================

-- Para ordenar la lista de invitados por "Recién escaneados"
alter table public.tickets 
add column if not exists scanned_at timestamptz;

comment on column public.tickets.scanned_at is 'Fecha y hora del último escaneo válido';
