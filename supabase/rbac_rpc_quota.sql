-- ==========================================
-- RBAC PHASE 4: ATOMIC RPC FOR QUOTAS
-- Run this in Supabase SQL Editor
-- ==========================================

create or replace function public.increment_event_quota(p_event_id uuid, p_user_id uuid)
returns boolean
as $$
declare
  v_limit int;
  v_used int;
begin
  -- 1. Select for update to lock the row
  select quota_limit, quota_used into v_limit, v_used
  from public.event_staff
  where event_id = p_event_id and user_id = p_user_id
  for update;

  if not found then
    return false; -- Not assigned to this event
  end if;

  -- 2. Check if quota available
  if v_used >= v_limit then
    return false; -- Quota reached
  end if;

  -- 3. Increment
  update public.event_staff
  set quota_used = quota_used + 1
  where event_id = p_event_id and user_id = p_user_id;

  return true;
end;
$$ language plpgsql security definer;
