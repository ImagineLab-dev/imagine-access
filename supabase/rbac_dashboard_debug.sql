-- ==========================================
-- DASHBOARD RPC: DIAGNÓSTICO PROFUNDO (V4)
-- ==========================================

create or replace function public.get_staff_dashboard(p_event_id uuid)
returns jsonb
as $$
declare
  v_role text;
  v_uid uuid;
  v_result jsonb;
  v_total_event_tickets int;
begin
  -- 1. Capturar identidad exacta
  v_uid := auth.uid();
  v_role := coalesce(
    auth.jwt() -> 'app_metadata' ->> 'role',
    auth.jwt() -> 'user_metadata' ->> 'role',
    'unknown'
  );

  -- 2. Conteo global para verificar si existen tickets en el evento (Depuración)
  select count(*) into v_total_event_tickets 
  from public.tickets 
  where event_id = p_event_id;

  -- 3. Caso RRPP (o cualquier rol que no sea admin para probar)
  if v_role = 'rrpp' or v_role = 'unknown' then
    select jsonb_build_object(
      'my_sales', count(id),
      'my_revenue', coalesce(sum(price), 0),
      'my_invitations_used', count(id) filter (where type = 'invitation' and status = 'used'),
      'my_invitations_total', count(id) filter (where type = 'invitation'),
      'my_quota', coalesce((select quota_limit from public.event_staff where event_id = p_event_id and user_id = v_uid), 0),
      -- METADATA DE DEPURACIÓN
      'debug_uid', v_uid,
      'debug_role', v_role,
      'debug_total_event', v_total_event_tickets,
      'debug_last_ticket_ref', (select buyer_name from public.tickets where event_id = p_event_id order by created_at desc limit 1)
    ) into v_result
    from public.tickets
    where event_id = p_event_id and created_by = v_uid;

  -- 4. Caso ADMIN
  else
    select jsonb_build_object(
      'total_sold', count(id),
      'scanned', count(id) filter (where status = 'used'),
      'valid', count(id) filter (where status = 'valid'),
      'revenue', coalesce(sum(price), 0),
      'invitations_total', count(id) filter (where type = 'invitation'),
      'invitations_scanned', count(id) filter (where type = 'invitation' and status = 'used'),
      'debug_uid', v_uid,
      'debug_role', v_role
    ) into v_result
    from public.tickets
    where event_id = p_event_id;
  end if;

  -- Si el resultado es nulo por alguna razón, devolver error controlado
  return coalesce(v_result, jsonb_build_object('error', 'No se pudieron generar métricas', 'debug_uid', v_uid));
end;
$$ language plpgsql security definer;
