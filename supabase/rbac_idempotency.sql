-- ==========================================
-- RBAC PHASE 7: IDEMPOTENCY
-- Run this in Supabase SQL Editor
-- ==========================================

-- 1. Add request_id to tickets
alter table public.tickets add column if not exists request_id uuid unique;

-- 2. Add request_id to checkins
alter table public.checkins add column if not exists request_id uuid unique;

-- 3. Index for performance
create index if not exists idx_tickets_request_id on public.tickets(request_id);
create index if not exists idx_checkins_request_id on public.checkins(request_id);
