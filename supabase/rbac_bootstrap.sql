-- ==========================================
-- RBAC & PROFESSIONAL FEATURES (Migration Script)
-- Run this in Supabase SQL Editor
-- ==========================================

-- 1. EVENT STAFF (Assignments & Quotas)
create table if not exists public.event_staff (
  id uuid primary key default uuid_generate_v4(),
  event_id uuid references public.events(id) not null,
  user_id uuid references auth.users(id) not null,
  role text not null check (role in ('rrpp', 'door')),
  quota_limit int default 0,
  quota_used int default 0 check (quota_used <= quota_limit),
  assigned_at timestamptz default now(),
  unique (event_id, user_id)
);

-- 2. AUDIT LOGS (Security & Traceability)
create table if not exists public.audit_logs (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references auth.users(id),
  action text not null, -- 'create_ticket', 'scan_qr', 'login_device'
  resource text, -- 'ticket_xyz', 'event_abc'
  details jsonb,
  ip_address text,
  created_at timestamptz default now()
);

-- 3. RLS UPDATES
alter table public.event_staff enable row level security;
alter table public.audit_logs enable row level security;

-- Event Staff Policies
create policy "Admin manages staff" on public.event_staff
  for all using (auth.jwt() -> 'app_metadata' ->> 'role' = 'admin');

create policy "Staff views own assignments" on public.event_staff
  for select using (auth.uid() = user_id);

-- Audit Logs Policies
create policy "Admin views audit logs" on public.audit_logs
  for select using (auth.jwt() -> 'app_metadata' ->> 'role' = 'admin');

create policy "Services insert logs" on public.audit_logs
  for insert with check (true);

-- 4. ROLE SYNC TRIGGER (Auth <-> Profile)
create or replace function public.handle_user_role_update() 
returns trigger as $$
begin
  -- Update the auth.users raw_app_meta_data with the new role
  update auth.users
  set raw_app_meta_data = 
    coalesce(raw_app_meta_data, '{}'::jsonb) || 
    jsonb_build_object('role', new.role)
  where id = new.user_id;
  return new;
end;
$$ language plpgsql security definer;

-- 2. Create the trigger on users_profile
drop trigger if exists on_role_change on public.users_profile;
create trigger on_role_change
  after update of role on public.users_profile
  for each row execute procedure public.handle_user_role_update();

-- 3. Also trigger on insert to ensure initial sync if created directly in DB
drop trigger if exists on_role_insert on public.users_profile;
create trigger on_role_insert
  after insert on public.users_profile
  for each row execute procedure public.handle_user_role_update();

-- 4. Initial Sync: Update all existing users based on current profile
do $$
declare
  r record;
begin
  for r in select user_id, role from public.users_profile loop
    update auth.users
    set raw_app_meta_data = 
      coalesce(raw_app_meta_data, '{}'::jsonb) || 
      jsonb_build_object('role', r.role)
    where id = r.user_id;
  end loop;
end;
$$;
