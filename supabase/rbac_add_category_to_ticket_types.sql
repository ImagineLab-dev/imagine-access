-- ==========================================
-- FEATURE: CLASIFICACIÓN DE TICKETS (STAFF/GUEST)
-- ==========================================

-- 1. Agregar columna category a ticket_types
alter table public.ticket_types 
add column if not exists category text default 'standard'; -- 'standard', 'staff', 'guest'

comment on column public.ticket_types.category is 'Clasificación especial del ticket (standard, staff, guest)';

-- 2. Actualizar RPC get_staff_dashboard para incluir métricas de Staff/Guest
create or replace function public.get_staff_dashboard(p_event_id uuid)
returns jsonb
as $$
declare
  v_role text;
  v_uid uuid;
  v_result jsonb;
begin
  -- 1. Obtener contexto de sesión
  v_uid := auth.uid();
  v_role := coalesce(
    auth.jwt() -> 'app_metadata' ->> 'role',
    auth.jwt() -> 'user_metadata' ->> 'role',
    'rrpp'
  );

  -- 2. ADMIN DASHBOARD & DOOR DASHBOARD (Comparten métricas globales)
  if v_role = 'admin' or v_role = 'door' then
    select jsonb_build_object(
      -- Métricas Generales
      'total_sold', count(t.id),
      'scanned', count(t.id) filter (where t.status = 'used'),
      'valid', count(t.id) filter (where t.status = 'valid'),
      'revenue', coalesce(sum(t.price), 0),
      
      -- STAFF Metrics (Joineando por nombre y event_id, ya que tickets.type es el nombre)
      'staff_created', (
          select count(t2.id) 
          from public.tickets t2 
          join public.ticket_types tt on t2.event_id = tt.event_id and t2.type = tt.name
          where t2.event_id = p_event_id and tt.category = 'staff'
      ),
      'staff_entered', (
          select count(t2.id) 
          from public.tickets t2 
          join public.ticket_types tt on t2.event_id = tt.event_id and t2.type = tt.name
          where t2.event_id = p_event_id and tt.category = 'staff' and t2.status = 'used'
      ),

      -- GUEST Metrics
      'guest_created', (
          select count(t2.id) 
          from public.tickets t2 
          join public.ticket_types tt on t2.event_id = tt.event_id and t2.type = tt.name
          where t2.event_id = p_event_id and tt.category = 'guest'
      ),
      'guest_entered', (
          select count(t2.id) 
          from public.tickets t2 
          join public.ticket_types tt on t2.event_id = tt.event_id and t2.type = tt.name
          where t2.event_id = p_event_id and tt.category = 'guest' and t2.status = 'used'
      ),

      'debug_role', v_role
    ) into v_result
    from public.tickets t
    where t.event_id = p_event_id;

  -- 3. RRPP DASHBOARD
  elsif v_role = 'rrpp' then
    select jsonb_build_object(
      'my_sales', count(id),
      'my_revenue', coalesce(sum(price), 0),
      'my_invitations_used', count(id) filter (where type = 'invitation' and status = 'used'),
      'my_quota', coalesce((select quota_limit from public.event_staff where event_id = p_event_id and user_id = v_uid), 0),
      'debug_role', v_role
    ) into v_result
    from public.tickets
    where event_id = p_event_id and created_by = v_uid;

  else
    return jsonb_build_object('error', 'Rol no reconocido');
  end if;

  return v_result;
end;
$$ language plpgsql security definer;
