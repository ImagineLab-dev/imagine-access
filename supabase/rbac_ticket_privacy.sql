-- ==========================================
-- RBAC FINAL: PRIVACIDAD DE TICKETS (CORREGIDO)
-- ==========================================

-- 1. Limpiar políticas anteriores
drop policy if exists "Read tickets scoped" on public.tickets;
drop policy if exists "Read tickets" on public.tickets;

-- 2. Crear nueva política con restricciones estrictas
create policy "Read tickets scoped" on public.tickets
for select using (
  -- ADMIN: Ve TODO
  (auth.jwt() -> 'app_metadata' ->> 'role' = 'admin') 
  OR
  -- RRPP: ÚNICAMENTE lo que él vendió o invitó
  (
    (auth.jwt() -> 'app_metadata' ->> 'role' = 'rrpp') 
    AND (created_by = auth.uid())
  )
  OR
  -- DOOR: Ve todo lo del evento que tiene asignado (para poder validar)
  (
    (auth.jwt() -> 'app_metadata' ->> 'role' = 'door') 
    AND (event_id in (select event_id from public.event_staff where user_id = auth.uid()))
  )
);
