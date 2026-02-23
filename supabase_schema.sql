-- ⚠️ ZONA DE LIMPIEZA (DROP)
drop table if exists public.checkins cascade;
drop table if exists public.tickets cascade;
drop table if exists public.ticket_types cascade;
drop table if exists public.devices cascade;
drop table if exists public.users_profile cascade;
drop table if exists public.events cascade;
drop table if exists public.app_settings cascade;

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- 1. Events Table
create table public.events (
  id uuid primary key default uuid_generate_v4(),
  slug text unique not null,
  name text not null,
  date timestamptz not null,
  venue text,
  address text, -- New: Address
  city text,    -- New: City
  currency text default 'PYG', -- New: Event Currency
  is_active boolean default true, -- Visible/Selling
  is_archived boolean default false, -- Soft Delete
  created_by uuid references auth.users(id),
  created_at timestamptz default now()
);

-- 2. Ticket Types (New Table)
create table public.ticket_types (
  id uuid primary key default uuid_generate_v4(),
  event_id uuid references public.events(id) on delete cascade not null,
  name text not null, -- 'General', 'VIP'
  price numeric default 0,
  currency text default 'PYG',
  is_active boolean default true,
  created_at timestamptz default now()
);

-- 3. Users Profile
create table public.users_profile (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('admin', 'rrpp', 'door')),
  display_name text,
  active boolean default true, -- Login access control
  created_at timestamptz default now()
);

-- 4. Devices (For Door Login)
create table public.devices (
  device_id text primary key,
  alias text,
  pin_hash text not null,
  enabled boolean default true,
  role text default 'door',
  created_at timestamptz default now()
);

-- 5. Tickets
create table public.tickets (
  id uuid primary key default uuid_generate_v4(),
  event_id uuid references public.events(id) not null,
  ticket_type_id uuid references public.ticket_types(id), -- New: Link to Type
  type text not null, -- Stores the name snapshot (e.g. 'VIP')
  price numeric default 0, -- Snapshot of price at purchase
  currency text default 'PYG', -- Snapshot of currency
  buyer_name text not null,
  buyer_email text not null,
  buyer_phone text,
  buyer_doc text,
  status text not null default 'valid' check (status in ('valid', 'used', 'void')),
  created_by uuid references auth.users(id),
  created_at timestamptz default now(),
  email_sent_at timestamptz,
  pdf_path text,
  pdf_url text,
  qr_token text unique not null,
  void_reason text
);

-- 6. Checkins (Scan Logs)
create table public.checkins (
  id uuid primary key default uuid_generate_v4(),
  ticket_id uuid references public.tickets(id),
  event_id uuid references public.events(id),
  scanned_at timestamptz default now(),
  device_id text references public.devices(device_id),
  operator_user uuid references auth.users(id),
  result text not null,
  message text
);

-- 7. App Settings (New Table)
create table public.app_settings (
  setting_key text primary key,
  setting_value text,
  description text
);

-- Initial Settings
insert into public.app_settings (setting_key, setting_value, description)
values ('default_currency', 'PYG', 'Moneda por defecto para nuevos eventos');


-- RLS POLICIES
alter table public.events enable row level security;
alter table public.ticket_types enable row level security;
alter table public.users_profile enable row level security;
alter table public.devices enable row level security;
alter table public.tickets enable row level security;
alter table public.checkins enable row level security;
alter table public.app_settings enable row level security;

-- Basic Read Policies (Authenticated)
create policy "Read Events" on public.events for select to authenticated using (true);
create policy "Read Types" on public.ticket_types for select to authenticated using (true);
create policy "Read Profiles" on public.users_profile for select to authenticated using (true);
create policy "Read Tickets" on public.tickets for select to authenticated using (true);
create policy "Read Devices" on public.devices for select to authenticated using (true);
create policy "Read Settings" on public.app_settings for select to authenticated using (true);

-- Write Policies (Tickets & Checkins)
create policy "Insert Tickets" on public.tickets for insert to authenticated with check (true);
create policy "Update Tickets" on public.tickets for update to authenticated using (true);
create policy "Insert Checkins" on public.checkins for insert to authenticated with check (true);

-- ADMIN POLICIES (Full CRUD)
-- Events
create policy "Admin CRUD Events" on public.events for all to authenticated 
using (exists (select 1 from public.users_profile where user_id = auth.uid() and role = 'admin'));

-- Ticket Types
create policy "Admin CRUD Types" on public.ticket_types for all to authenticated
using (exists (select 1 from public.users_profile where user_id = auth.uid() and role = 'admin'));

-- Users & Roles - FIXED: Avoid infinite recursion
-- Allow users to SELECT their own profile
create policy "Users Read Own Profile" on public.users_profile for select to authenticated
using (user_id = auth.uid());

-- Admins can do everything (using JWT claims to avoid recursion)
create policy "Admin Modify Profiles" on public.users_profile for insert to authenticated
with check ((auth.jwt()->>'role')::text = 'admin' OR user_id = auth.uid());

create policy "Admin Update Profiles" on public.users_profile for update to authenticated
using ((auth.jwt()->>'role')::text = 'admin' OR user_id = auth.uid());

create policy "Admin Delete Profiles" on public.users_profile for delete to authenticated
using ((auth.jwt()->>'role')::text = 'admin');

-- Devices
create policy "Admin CRUD Devices" on public.devices for all to authenticated
using (exists (select 1 from public.users_profile where user_id = auth.uid() and role = 'admin'));

-- Settings
create policy "Admin CRUD Settings" on public.app_settings for all to authenticated
using (exists (select 1 from public.users_profile where user_id = auth.uid() and role = 'admin'));


-- Indexes
create index idx_tickets_qr_token on public.tickets(qr_token);
create index idx_tickets_buyer_email on public.tickets(buyer_email);
create index idx_checkins_ticket_id on public.checkins(ticket_id);
create index idx_events_slug on public.events(slug);
create index idx_ticket_types_event on public.ticket_types(event_id);


-- SETUP INICIAL
insert into storage.buckets (id, name, public) values ('tickets', 'tickets', true) on conflict (id) do nothing;

drop policy if exists "Uploads" on storage.objects;
create policy "Uploads" on storage.objects for insert to public with check (bucket_id = 'tickets');
drop policy if exists "Downloads" on storage.objects;
create policy "Downloads" on storage.objects for select to public using (bucket_id = 'tickets');

-- Datos Iniciales de Prueba
insert into public.events (slug, name, date, venue, address, currency, is_active)
values ('imagine-fest-2026', 'Imagine Fest 2026', now() + interval '30 days', 'Estadio Monumental', 'Av. Figueroa Alcorta 7597', 'PYG', true)
on conflict (slug) do nothing;

-- Tipos de prueba
do $$
declare
  eid uuid;
begin
  select id into eid from public.events where slug = 'imagine-fest-2026';
  
  if eid is not null then
    insert into public.ticket_types (event_id, name, price, currency)
    values 
      (eid, 'General', 150000, 'PYG'),
      (eid, 'VIP', 300000, 'PYG');
  end if;
end $$;

-- ⬇️ ¡IMPORTANTE! PON TU EMAIL AQUÍ ⬇️ --
-- (Descomenta y ejecuta esta parte final cambiando el email)

-- insert into public.users_profile (user_id, role, display_name)
-- select id, 'admin', 'Super Admin'
-- from auth.users
-- where email = 'TU_EMAIL_REAL@AQUI.COM'  <-- CAMBIA ESTO
-- on conflict (user_id) do update set role = 'admin';
