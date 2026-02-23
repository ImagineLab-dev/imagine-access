-- ==========================================
-- ULTIMATE MASTER MIGRATION: Imagine Access
-- Version: COMPLETE_SYSTEM_V1
-- Purpose: Ensures 100% functionality for Admin, RRPP, and Door.
-- ==========================================

BEGIN;

-- 1. SCHEMA HARDENING (Columns & Tables)
-- Tickets enhancements
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS scanned_at TIMESTAMPTZ DEFAULT NULL;
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'valid';

-- Ticket Types enhancements
ALTER TABLE public.ticket_types ADD COLUMN IF NOT EXISTS valid_until TIMESTAMPTZ DEFAULT NULL;
ALTER TABLE public.ticket_types ADD COLUMN IF NOT EXISTS color TEXT DEFAULT '#4F46E5';
ALTER TABLE public.ticket_types ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'standard';

-- Quota Management Table (event_staff)
CREATE TABLE IF NOT EXISTS public.event_staff (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID REFERENCES public.events(id) NOT NULL,
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('rrpp', 'door', 'admin')),
    
    -- Quotas
    quota_standard INT DEFAULT 0,
    quota_standard_used INT DEFAULT 0,
    quota_guest INT DEFAULT 0,
    quota_guest_used INT DEFAULT 0,
    quota_invitation INT DEFAULT 0,
    quota_invitation_used INT DEFAULT 0,
    
    assigned_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (event_id, user_id)
);

-- Ensure all quota columns exist if table was already there
ALTER TABLE public.event_staff ADD COLUMN IF NOT EXISTS quota_standard INT DEFAULT 0;
ALTER TABLE public.event_staff ADD COLUMN IF NOT EXISTS quota_standard_used INT DEFAULT 0;
ALTER TABLE public.event_staff ADD COLUMN IF NOT EXISTS quota_guest INT DEFAULT 0;
ALTER TABLE public.event_staff ADD COLUMN IF NOT EXISTS quota_guest_used INT DEFAULT 0;
ALTER TABLE public.event_staff ADD COLUMN IF NOT EXISTS quota_invitation INT DEFAULT 0;
ALTER TABLE public.event_staff ADD COLUMN IF NOT EXISTS quota_invitation_used INT DEFAULT 0;


-- 2. REAL-TIME SYNC SETUP
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        CREATE PUBLICATION supabase_realtime;
    END IF;
END $$;

DO $$
BEGIN
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.checkins;
    EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'Checkins ya en publicación'; END;
    
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.tickets;
    EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'Tickets ya en publicación'; END;
END $$;

ALTER TABLE public.checkins REPLICA IDENTITY FULL;
ALTER TABLE public.tickets REPLICA IDENTITY FULL;


-- 3. TRACEABILITY & AUDIT (Foreign Keys)
ALTER TABLE public.tickets DROP CONSTRAINT IF EXISTS tickets_created_by_fkey;
ALTER TABLE public.tickets ADD CONSTRAINT tickets_created_by_fkey
    FOREIGN KEY (created_by) REFERENCES public.users_profile(user_id);

ALTER TABLE public.checkins DROP CONSTRAINT IF EXISTS checkins_operator_user_fkey;
ALTER TABLE public.checkins ADD CONSTRAINT checkins_operator_user_fkey
    FOREIGN KEY (operator_user) REFERENCES public.users_profile(user_id);


-- 4. AUTOMATIC QUOTA TRIGGER
CREATE OR REPLACE FUNCTION public.increment_quota_usage()
RETURNS TRIGGER AS $$
DECLARE
    v_category TEXT;
BEGIN
    SELECT category INTO v_category FROM public.ticket_types 
    WHERE event_id = NEW.event_id AND name = NEW.type;

    IF v_category = 'guest' THEN
        UPDATE public.event_staff SET quota_guest_used = quota_guest_used + 1
        WHERE event_id = NEW.event_id AND user_id = NEW.created_by;
    ELSIF v_category = 'invitation' THEN
        UPDATE public.event_staff SET quota_invitation_used = quota_invitation_used + 1
        WHERE event_id = NEW.event_id AND user_id = NEW.created_by;
    ELSE -- standard, general, etc.
        UPDATE public.event_staff SET quota_standard_used = quota_standard_used + 1
        WHERE event_id = NEW.event_id AND user_id = NEW.created_by;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_ticket_created_quota ON public.tickets;
CREATE TRIGGER on_ticket_created_quota
    AFTER INSERT ON public.tickets
    FOR EACH ROW EXECUTE FUNCTION public.increment_quota_usage();


-- 5. DASHBOARD RPC (Robust & Zero-Safe)
CREATE OR REPLACE FUNCTION public.get_staff_dashboard(p_event_id uuid)
RETURNS jsonb AS $$
DECLARE
  v_role text; v_uid uuid; v_result jsonb;
BEGIN
  v_uid := auth.uid();
  v_role := coalesce(auth.jwt() -> 'app_metadata' ->> 'role', 'rrpp');

  IF v_role = 'admin' OR v_role = 'door' THEN
    v_result := jsonb_build_object(
      'total_sold', (SELECT count(*) FROM public.tickets WHERE event_id = p_event_id),
      'scanned', (SELECT count(*) FROM public.tickets WHERE event_id = p_event_id AND status = 'used'),
      'valid', (SELECT count(*) FROM public.tickets WHERE event_id = p_event_id AND status = 'valid'),
      'revenue', (SELECT coalesce(sum(price), 0) FROM public.tickets WHERE event_id = p_event_id),
      
      -- Granular categories
      'standard_created', (SELECT count(t2.id) FROM public.tickets t2 JOIN public.ticket_types tt ON t2.type = tt.name WHERE t2.event_id = p_event_id AND tt.category = 'standard'),
      'standard_entered', (SELECT count(t2.id) FROM public.tickets t2 JOIN public.ticket_types tt ON t2.type = tt.name WHERE t2.event_id = p_event_id AND tt.category = 'standard' AND t2.status = 'used'),
      'staff_created', (SELECT count(t2.id) FROM public.tickets t2 JOIN public.ticket_types tt ON t2.type = tt.name WHERE t2.event_id = p_event_id AND tt.category = 'staff'),
      'staff_entered', (SELECT count(t2.id) FROM public.tickets t2 JOIN public.ticket_types tt ON t2.type = tt.name WHERE t2.event_id = p_event_id AND tt.category = 'staff' AND t2.status = 'used'),
      'guest_created', (SELECT count(t2.id) FROM public.tickets t2 JOIN public.ticket_types tt ON t2.type = tt.name WHERE t2.event_id = p_event_id AND tt.category = 'guest'),
      'guest_entered', (SELECT count(t2.id) FROM public.tickets t2 JOIN public.ticket_types tt ON t2.type = tt.name WHERE t2.event_id = p_event_id AND tt.category = 'guest' AND t2.status = 'used')
    );
  ELSIF v_role = 'rrpp' THEN
    v_result := (
        SELECT jsonb_build_object(
          'my_sales', (SELECT count(*) FROM public.tickets WHERE event_id = p_event_id AND created_by = v_uid),
          'my_revenue', (SELECT coalesce(sum(price), 0) FROM public.tickets WHERE event_id = p_event_id AND created_by = v_uid),
          
          -- Detailed granular quotas
          'quota_standard', es.quota_standard,
          'quota_standard_used', es.quota_standard_used,
          'quota_guest', es.quota_guest,
          'quota_guest_used', es.quota_guest_used,
          'quota_invitation', es.quota_invitation,
          'quota_invitation_used', es.quota_invitation_used
        )
        FROM public.event_staff es
        WHERE es.event_id = p_event_id AND es.user_id = v_uid
    );
    -- Fallback if not assigned to event
    IF v_result IS NULL THEN
        v_result := jsonb_build_object('my_sales', 0, 'my_revenue', 0, 'quota_standard', 0, 'quota_standard_used', 0);
    END IF;
  END IF;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 6. STATISTICS RPC (Admin Visualization)
CREATE OR REPLACE FUNCTION public.get_event_statistics(p_event_id uuid)
RETURNS jsonb AS $$
DECLARE v_stats jsonb;
BEGIN
  SELECT jsonb_build_object(
    'attendance_by_hour', (
      SELECT jsonb_agg(h) FROM (
        SELECT to_char(date_trunc('hour', scanned_at), 'HH24:00') AS hour, count(*) AS count
        FROM public.checkins WHERE event_id = p_event_id AND result = 'allowed' GROUP BY 1 ORDER BY 1
      ) h
    ),
    'rrpp_performance', (
      SELECT jsonb_agg(p) FROM (
        SELECT coalesce(up.display_name, u.email) AS name, t.type, count(*) AS count
        FROM public.tickets t LEFT JOIN public.users_profile up ON t.created_by = up.user_id
        WHERE t.event_id = p_event_id GROUP BY 1, 2 ORDER BY 3 DESC
      ) p
    ),
    'sales_timeline', (
      SELECT jsonb_agg(s) FROM (
        SELECT created_at::date AS day, count(*) AS count, sum(price) AS revenue
        FROM public.tickets WHERE event_id = p_event_id GROUP BY 1 ORDER BY 1
      ) s
    )
  ) INTO v_stats;
  RETURN v_stats;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
