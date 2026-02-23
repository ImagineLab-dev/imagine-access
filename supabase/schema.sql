-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- EVENTS Table
create table public.events (
  id uuid primary key default uuid_generate_v4(),
  slug text unique not null,
  name text not null,
  date timestamptz not null,
  venue text not null,
  is_active boolean default true,
  created_by uuid references auth.users(id),
  created_at timestamptz default now()
);

-- TICKETS Table
create table public.tickets (
  id uuid primary key default uuid_generate_v4(),
  event_id uuid references public.events(id) not null,
  type text not null, -- 'vip', 'general', 'invitation'
  price numeric default 0,
  buyer_name text not null,
  buyer_email text not null,
  buyer_phone text,
  buyer_doc text,
  status text default 'valid', -- 'valid', 'used', 'void'
  created_by uuid references auth.users(id),
  created_at timestamptz default now(),
  email_sent_at timestamptz,
  pdf_url text,
  qr_token text unique
);

-- CHECKINS Table
create table public.checkins (
  id uuid primary key default uuid_generate_v4(),
  ticket_id uuid references public.tickets(id) not null,
  event_id uuid references public.events(id) not null,
  scanned_at timestamptz default now(),
  device_id text,
  operator_user uuid references auth.users(id),
  result text -- 'allowed', 'already_used', 'void', 'not_found'
);

-- DEVICES Table (for Door login)
create table public.devices (
  id text primary key, -- device_id from app
  alias text,
  pin text not null, -- hashed or plain? plain for simplicity in MVP, but hashed ideally.
  enabled boolean default true,
  last_active_at timestamptz
);

-- RLS Policies (Basic Setup)
alter table public.events enable row level security;
alter table public.tickets enable row level security;
alter table public.checkins enable row level security;
alter table public.devices enable row level security;

-- Admin/RRPP can view events
create policy "Enable read access for authenticated users" on public.events for select using (auth.role() = 'authenticated');
-- Admin can insert events
create policy "Enable insert for authenticated users" on public.events for insert with check (auth.role() = 'authenticated');

-- Tickets: RRPP can see tickets they created, Admin can see all (simplified to auth for now)
create policy "Read tickets" on public.tickets for select using (auth.role() = 'authenticated');
create policy "Insert tickets" on public.tickets for insert with check (auth.role() = 'authenticated');

-- Storage Bucket for PDFs
insert into storage.buckets (id, name, public) values ('tickets', 'tickets', true);
create policy "Public Access to Ticket PDFs" on storage.objects for select using ( bucket_id = 'tickets' );

-- ==========================================
-- RBAC & PROFESSIONAL FEATURES (Phase 2)
-- ==========================================

-- 1. EVENT STAFF (Assignments & Quotas)
create table public.event_staff (
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
create table public.audit_logs (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references auth.users(id),
  action text not null, -- 'create_ticket', 'scan_qr', 'login_device'
  resource text, -- 'ticket_xyz', 'event_abc'
  details jsonb,
  ip_address text,
  created_at timestamptz default now()
);

-- 3. ROLE SYNC TRIGGER (Auth <-> Profile)
-- Ensures auth.users.raw_app_meta_data['role'] matches users_profile.role
create or replace function public.handle_user_role_update() 
returns trigger as $$
begin
  update auth.users
  set raw_app_meta_data = 
    coalesce(raw_app_meta_data, '{}'::jsonb) || 
    jsonb_build_object('role', new.role)
  where id = new.user_id;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_role_change on public.users_profile;
create trigger on_role_change
  after update of role on public.users_profile
  for each row execute procedure public.handle_user_role_update();

drop trigger if exists on_role_insert on public.users_profile;
create trigger on_role_insert
  after insert on public.users_profile
  for each row execute procedure public.handle_user_role_update();

-- 4. RLS UPDATES
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
  for insert with check (true); -- Usually inserted by Edge Functions (service_role)
