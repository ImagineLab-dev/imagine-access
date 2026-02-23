-- ==========================================
-- FIX: AGREGAR COLUMNA METHOD A CHECKINS
-- ==========================================

alter table public.checkins 
add column if not exists method text; -- 'qr', 'doc', 'id'

-- Comentario para documentación
comment on column public.checkins.method is 'Método de validación utilizado (qr, doc, id)';
