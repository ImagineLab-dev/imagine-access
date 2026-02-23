-- ==========================================
-- FIX: AGREGAR COLUMNA NOTES A CHECKINS
-- ==========================================

alter table public.checkins 
add column if not exists notes text;

-- Comentario para documentación
comment on column public.checkins.notes is 'Notas o motivos de la validación manual';
