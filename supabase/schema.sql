-- ==========================================================
-- IMAGINE-ACCESS — Consolidated Schema (post-migrations)
-- Last updated: 2026-03-08
-- ==========================================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ==========================================
-- ORGANIZATIONS
-- ==========================================
create table public.organizations (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  slug text unique not null,
  owner_id uuid references auth.users(id),
  created_at timestamptz default now()
);

alter table public.organizations enable row level security;

create policy "Authenticated users can read own org" on public.organizations
  for select using (auth.role() = 'authenticated');

-- ==========================================
-- USER PROFILES
-- ==========================================
create table public.users_profile (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid unique references auth.users(id) not null,
  display_name text,
  role text not null default 'rrpp' check (role in ('admin', 'rrpp', 'door')),
  organization_id uuid references public.organizations(id),
  created_at timestamptz default now()
);

alter table public.users_profile enable row level security;

create policy "Users read own profile" on public.users_profile
  for select using (auth.uid() = user_id);

-- ==========================================
-- EVENTS
-- ==========================================
create table public.events (
  id uuid primary key default uuid_generate_v4(),
  slug text unique not null,
  name text not null,
  date timestamptz not null,
  venue text not null,
  address text,
  city text,
  currency text default 'PYG',
  is_active boolean default true,
  is_archived boolean default false,
  organization_id uuid references public.organizations(id),
  created_by uuid references auth.users(id),
  created_at timestamptz default now()
);

alter table public.events enable row level security;

create policy "Enable read access for authenticated users" on public.events
  for select using (auth.role() = 'authenticated');
create policy "Enable insert for authenticated users" on public.events
  for insert with check (auth.role() = 'authenticated');

-- ==========================================
-- TICKET TYPES
-- ==========================================
create table public.ticket_types (
  id uuid primary key default uuid_generate_v4(),
  event_id uuid references public.events(id) not null,
  name text not null,
  price numeric default 0,
  currency text default 'PYG',
  category text default 'standard',
  color text,
  valid_until timestamptz,
  is_active boolean default true,
  created_at timestamptz default now()
);

alter table public.ticket_types enable row level security;

create policy "Read ticket types" on public.ticket_types
  for select using (auth.role() = 'authenticated');

-- ==========================================
-- TICKETS
-- ==========================================
create table public.tickets (
  id uuid primary key default uuid_generate_v4(),
  event_id uuid references public.events(id) not null,
  type text not null,
  price numeric default 0,
  buyer_name text not null,
  buyer_email text not null,
  buyer_phone text,
  buyer_doc text,
  status text default 'valid' check (status in ('valid', 'used', 'void')),
  void_reason text,
  scanned_at timestamptz,
  request_id text,
  created_by uuid references auth.users(id),
  created_at timestamptz default now(),
  email_sent_at timestamptz,
  pdf_url text,
  qr_token text unique
);

alter table public.tickets enable row level security;

create policy "Read tickets" on public.tickets
  for select using (auth.role() = 'authenticated');
create policy "Insert tickets" on public.tickets
  for insert with check (auth.role() = 'authenticated');

-- ==========================================
-- CHECKINS
-- ==========================================
create table public.checkins (
  id uuid primary key default uuid_generate_v4(),
  ticket_id uuid references public.tickets(id) not null,
  event_id uuid references public.events(id) not null,
  scanned_at timestamptz default now(),
  device_id text,
  operator_user uuid references auth.users(id),
  result text,
  method text,
  notes text,
  request_id text
);

alter table public.checkins enable row level security;

-- ==========================================
-- DEVICES (for Door login)
-- ==========================================
create table public.devices (
  id text primary key,
  device_id text,
  alias text,
  pin text,
  pin_hash text,
  pin_salt text,
  enabled boolean default true,
  organization_id uuid references public.organizations(id),
  last_active_at timestamptz,
  created_at timestamptz default now()
);

alter table public.devices enable row level security;

-- ==========================================
-- APP SETTINGS
-- ==========================================
create table public.app_settings (
  id uuid primary key default uuid_generate_v4(),
  setting_key text not null,
  setting_value text,
  organization_id uuid references public.organizations(id),
  unique (setting_key, organization_id)
);

alter table public.app_settings enable row level security;

-- ==========================================
-- RBAC & PROFESSIONAL FEATURES
-- ==========================================

-- EVENT STAFF (Assignments & Quotas)
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

alter table public.event_staff enable row level security;

create policy "Admin manages staff" on public.event_staff
  for all using (auth.jwt() -> 'app_metadata' ->> 'role' = 'admin');
create policy "Staff views own assignments" on public.event_staff
  for select using (auth.uid() = user_id);

-- AUDIT LOGS (Security & Traceability)
create table public.audit_logs (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references auth.users(id),
  action text not null,
  resource text,
  details jsonb,
  ip_address text,
  created_at timestamptz default now()
);

alter table public.audit_logs enable row level security;

create policy "Admin views audit logs" on public.audit_logs
  for select using (auth.jwt() -> 'app_metadata' ->> 'role' = 'admin');
create policy "Services insert logs" on public.audit_logs
  for insert with check (true);

-- ==========================================
-- ROLE SYNC TRIGGER (Auth <-> Profile)
-- ==========================================
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
$$ language plpgsql security definer set search_path = public, pg_temp;

drop trigger if exists on_role_change on public.users_profile;
create trigger on_role_change
  after update of role on public.users_profile
  for each row execute procedure public.handle_user_role_update();

drop trigger if exists on_role_insert on public.users_profile;
create trigger on_role_insert
  after insert on public.users_profile
  for each row execute procedure public.handle_user_role_update();

-- ==========================================
-- STORAGE
-- ==========================================
insert into storage.buckets (id, name, public) values ('tickets', 'tickets', false);
