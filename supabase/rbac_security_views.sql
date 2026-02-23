-- ==========================================
-- RBAC PHASE 3: SECURE VIEWS & GRANULAR RLS
-- Run this in Supabase SQL Editor
-- ==========================================

-- 1. CLARIFY RRPP TICKET VISIBILITY
-- RRPP can ONLY see tickets they created OR for events they are assigned to.
drop policy if exists "Read tickets" on public.tickets;
create policy "Read tickets scoped" on public.tickets
for select using (
  auth.jwt() -> 'app_metadata' ->> 'role' = 'admin' OR
  (
    auth.jwt() -> 'app_metadata' ->> 'role' = 'rrpp' AND 
    (
      created_by = auth.uid() OR 
      event_id in (select event_id from public.event_staff where user_id = auth.uid())
    )
  ) OR
  (
    auth.jwt() -> 'app_metadata' ->> 'role' = 'door' AND 
    event_id in (select event_id from public.event_staff where user_id = auth.uid())
  )
);

-- 2. DOOR STAFF CHECKIN INSERT
drop policy if exists "Enable insert for authenticated users" on public.checkins;
create policy "Door insert checkins" on public.checkins
for insert with check (
  auth.jwt() -> 'app_metadata' ->> 'role' = 'admin' OR
  (
    auth.jwt() -> 'app_metadata' ->> 'role' = 'door' AND 
    event_id in (select event_id from public.event_staff where user_id = auth.uid())
  )
);

-- 3. SECURE DASHBOARD RPC
-- Returns metrics based on the caller's role for a specific event.
create or replace function public.get_staff_dashboard(p_event_id uuid)
returns jsonb
as $$
declare
  v_role text;
  v_result jsonb;
begin
  -- Get user role from app_metadata
  v_role := auth.jwt() -> 'app_metadata' ->> 'role';

  -- ADMIN DASHBOARD (Full Info)
  if v_role = 'admin' then
    select jsonb_build_object(
      'total_sold', count(id),
      'scanned', count(id) filter (where status = 'used'),
      'valid', count(id) filter (where status = 'valid'),
      'revenue', coalesce(sum(price), 0),
      'dashboard_type', 'admin'
    ) into v_result
    from public.tickets
    where event_id = p_event_id;

  -- RRPP DASHBOARD (My sales and quota)
  elsif v_role = 'rrpp' then
    select jsonb_build_object(
      'my_sales', count(id),
      'my_revenue', coalesce(sum(price), 0),
      'my_invitations_used', count(id) filter (where type = 'invitation' and status = 'used'),
      'my_quota', (select quota_limit from public.event_staff where event_id = p_event_id and user_id = auth.uid()),
      'dashboard_type', 'rrpp'
    ) into v_result
    from public.tickets
    where event_id = p_event_id and created_by = auth.uid();

  -- DOOR DASHBOARD (Operational Stats only)
  elsif v_role = 'door' then
    select jsonb_build_object(
      'total_sold', count(id),
      'scanned', count(id) filter (where status = 'used'),
      'valid', count(id) filter (where status = 'valid'),
      'dashboard_type', 'door'
    ) into v_result
    from public.tickets
    where event_id = p_event_id;

  else
    return jsonb_build_object('error', 'Unauthorized role');
  end if;

  return v_result;
end;
$$ language plpgsql security definer;
