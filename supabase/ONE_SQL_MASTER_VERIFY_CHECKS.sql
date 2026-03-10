-- =============================================================================
-- ONE SQL MASTER - VERIFY CHECKS
-- Run after executing ONE_SQL_MASTER_REVIEWED.sql
-- =============================================================================

-- 1) Required functions exist
select n.nspname as schema_name, p.proname as function_name
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'create_user_organization',
    'ensure_user_organization',
    'increment_event_quota',
    'search_tickets_unified',
    'get_device_tickets',
    'get_authorized_tickets',
    'manage_event_staff',
    'get_staff_dashboard',
    'get_event_statistics'
  )
order by p.proname;

-- 2) Critical columns for app + edge
select table_name, column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and (
    (table_name = 'events' and column_name in ('organization_id','address','city','is_archived','currency'))
    or (table_name = 'ticket_types' and column_name in ('category','color','valid_until','currency'))
    or (table_name = 'tickets' and column_name in ('status','scanned_at','email_sent_at','request_id'))
    or (table_name = 'checkins' and column_name in ('method','notes','request_id'))
    or (table_name = 'devices' and column_name in ('organization_id','pin_hash','pin_salt'))
    or (table_name = 'event_staff' and column_name in (
      'quota_limit','quota_used','quota_standard','quota_standard_used','quota_guest','quota_guest_used','quota_invitation','quota_invitation_used'
    ))
  )
order by table_name, column_name;

-- 3) Constraints used by upserts/idempotency
select conrelid::regclass::text as table_name, conname as constraint_name
from pg_constraint
where conname in (
  'tickets_request_id_unique',
  'checkins_request_id_unique',
  'event_staff_event_id_user_id_key'
)
order by conname;

-- 4) RLS enabled status
select schemaname, tablename, rowsecurity
from pg_tables
where schemaname = 'public'
  and tablename in (
    'organizations','users_profile','events','ticket_types','tickets','checkins','devices','event_staff','app_settings','audit_logs'
  )
order by tablename;

-- 5) Policies snapshot
select schemaname, tablename, policyname, cmd
from pg_policies
where schemaname = 'public'
  and tablename in (
    'organizations','users_profile','events','ticket_types','tickets','checkins','devices','event_staff','app_settings','audit_logs'
  )
order by tablename, policyname;

-- 6) Realtime publication
select pubname from pg_publication where pubname = 'supabase_realtime';

select p.pubname, c.relname as table_name
from pg_publication p
join pg_publication_rel pr on p.oid = pr.prpubid
join pg_class c on c.oid = pr.prrelid
where p.pubname = 'supabase_realtime'
  and c.relname in ('tickets','checkins')
order by c.relname;

-- 7) Storage bucket used by ticket email/PDF
select id, name, public
from storage.buckets
where id = 'tickets';

-- 8) Quick smoke probes (execute as authenticated admin in SQL editor session)
-- select public.get_staff_dashboard('<event_uuid>'::uuid);
-- select public.get_event_statistics('<event_uuid>'::uuid);
