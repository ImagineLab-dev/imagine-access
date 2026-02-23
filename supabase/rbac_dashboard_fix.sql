-- ==========================================
-- DASHBOARD RPC: ROBUSTEZ Y DEPURACIÓN (FINAL)
-- ==========================================

create or replace function public.get_staff_dashboard(p_event_id uuid)
returns jsonb
as $$
declare
  v_role text;
  v_uid uuid;
  v_result jsonb;
begin
  -- 1. Obtener contexto de sesión de forma segura
  v_uid := auth.uid();
  v_role := coalesce(
    auth.jwt() -> 'app_metadata' ->> 'role',
    auth.jwt() -> 'user_metadata' ->> 'role',
    'rrpp' -- Fallback razonable para staff si no hay rol en JWT
  );

  -- 2. ADMIN DASHBOARD
  if v_role = 'admin' then
    select jsonb_build_object(
      'total_sold', count(id),
      'scanned', count(id) filter (where status = 'used'),
      'valid', count(id) filter (where status = 'valid'),
      'revenue', coalesce(sum(price), 0),
      'debug_role', v_role,
      'debug_uid', v_uid
    ) into v_result
    from public.tickets
    where event_id = p_event_id;

  -- 3. RRPP DASHBOARD
  elsif v_role = 'rrpp' then
    select jsonb_build_object(
      'my_sales', count(id),
      'my_revenue', coalesce(sum(price), 0),
      'my_invitations_used', count(id) filter (where type = 'invitation' and status = 'used'),
      'my_quota', coalesce((select quota_limit from public.event_staff where event_id = p_event_id and user_id = v_uid), 0),
      'debug_role', v_role,
      'debug_uid', v_uid
    ) into v_result
    from public.tickets
    where event_id = p_event_id and created_by = v_uid;

  -- 4. DOOR DASHBOARD
  elsif v_role = 'door' then
    select jsonb_build_object(
      'total_sold', count(id),
      'scanned', count(id) filter (where status = 'used'),
      'valid', count(id) filter (where status = 'valid'),
      'debug_role', v_role,
      'debug_uid', v_uid
    ) into v_result
    from public.tickets
    where event_id = p_event_id;

  else
    return jsonb_build_object(
      'error', 'Rol no reconocido',
      'debug_role', v_role,
      'debug_uid', v_uid
    );
  end if;

  return v_result;
end;
$$ language plpgsql security definer;
