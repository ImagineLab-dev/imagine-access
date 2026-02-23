-- 1. Update get_staff_dashboard to include standard guests
create or replace function public.get_staff_dashboard(p_event_id uuid)
returns jsonb
as $$
declare
  v_role text;
  v_uid uuid;
  v_result jsonb;
begin
  -- 1. Obtener contexto de sesión (JWT)
  v_uid := auth.uid();
  v_role := coalesce(
    auth.jwt() -> 'app_metadata' ->> 'role',
    auth.jwt() -> 'user_metadata' ->> 'role',
    'rrpp'
  );

  -- 2. ADMIN DASHBOARD & DOOR DASHBOARD
  if v_role = 'admin' or v_role = 'door' then
    v_result := jsonb_build_object(
      'total_sold', (select count(*) from public.tickets where event_id = p_event_id),
      'scanned', (select count(*) from public.tickets where event_id = p_event_id and status = 'used'),
      'valid', (select count(*) from public.tickets where event_id = p_event_id and status = 'valid'),
      'revenue', (select coalesce(sum(price), 0) from public.tickets where event_id = p_event_id),
      
      -- STANDARD Metrics
      'standard_created', (
          select count(t2.id) 
          from public.tickets t2 
          join public.ticket_types tt on t2.event_id = tt.event_id and t2.type = tt.name
          where t2.event_id = p_event_id and tt.category = 'standard'
      ),
      'standard_entered', (
          select count(t2.id) 
          from public.tickets t2 
          join public.ticket_types tt on t2.event_id = tt.event_id and t2.type = tt.name
          where t2.event_id = p_event_id and tt.category = 'standard' and t2.status = 'used'
      ),

      -- STAFF Metrics
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

      -- GUEST Metrics (Invitations)
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

      'debug_role', v_role,
      'debug_event', p_event_id
    );

  -- 3. RRPP DASHBOARD
  elsif v_role = 'rrpp' then
    v_result := jsonb_build_object(
      'my_sales', (select count(*) from public.tickets where event_id = p_event_id and created_by = v_uid),
      'my_revenue', (select coalesce(sum(price), 0) from public.tickets where event_id = p_event_id and created_by = v_uid),
      'my_invitations_used', (select count(*) from public.tickets where event_id = p_event_id and created_by = v_uid and (type = 'invitation' or type = 'invitado') and status = 'used'),
      'my_quota', coalesce((select quota_limit from public.event_staff where event_id = p_event_id and user_id = v_uid), 0),
      'debug_role', v_role,
      'debug_event', p_event_id
    );

  else
    v_result := jsonb_build_object('error', 'Rol no reconocido', 'debug_role', v_role);
  end if;

  return v_result;
end;
$$ language plpgsql security definer;

-- 2. New RPC for detailed statistics (Admin only)
create or replace function public.get_event_statistics(p_event_id uuid)
returns jsonb
as $$
declare
  v_role text;
  v_stats jsonb;
begin
  -- Control de acceso
  v_role := auth.jwt() -> 'app_metadata' ->> 'role';
  if v_role != 'admin' then
    raise exception 'Unauthorized: Statistics only available for Admin role';
  end if;

  select jsonb_build_object(
    -- Chart 1: People entering per hour
    'attendance_by_hour', (
      select jsonb_agg(h)
      from (
        select 
          to_char(date_trunc('hour', scanned_at), 'HH24:00') as hour,
          count(*) as count
        from public.checkins
        where event_id = p_event_id and result = 'allowed'
        group by 1
        order by 1
      ) h
    ),
    
    -- Chart 2: Tickets/Type by User
    'rrpp_performance', (
      select jsonb_agg(p)
      from (
        select 
          coalesce(up.display_name, u.email) as name,
          t.type,
          count(*) as count
        from public.tickets t
        left join auth.users u on t.created_by = u.id
        left join public.users_profile up on u.id = up.user_id
        where t.event_id = p_event_id
        group by 1, 2
        order by 3 desc
      ) p
    ),
    
    -- Chart 3: Sales trend (days closest to event)
    'sales_timeline', (
      select jsonb_agg(s)
      from (
        select 
          created_at::date as day,
          count(*) as count,
          sum(price) as revenue
        from public.tickets
        where event_id = p_event_id
        group by 1
        order by 1
      ) s
    )
  ) into v_stats;

  return v_stats;
end;
$$ language plpgsql security definer;
