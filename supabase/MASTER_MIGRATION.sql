-- ==========================================
-- MASTER MIGRATION: Imagine Access (Real-Time & Traceability)
-- ==========================================

BEGIN;

-- 1. ENABLE REALTIME SYNC
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
    EXCEPTION WHEN OTHERS THEN 
        RAISE NOTICE 'Table checkins already in publication';
    END;

    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.tickets;
    EXCEPTION WHEN OTHERS THEN 
        RAISE NOTICE 'Table tickets already in publication';
    END;
END $$;

ALTER TABLE public.checkins REPLICA IDENTITY FULL;
ALTER TABLE public.tickets REPLICA IDENTITY FULL;


-- 2. TICKET TRACEABILITY (RELATIONSHIPS)
ALTER TABLE public.tickets DROP CONSTRAINT IF EXISTS tickets_created_by_fkey;
ALTER TABLE public.tickets ADD CONSTRAINT tickets_created_by_fkey
    FOREIGN KEY (created_by) REFERENCES public.users_profile(user_id);

ALTER TABLE public.checkins DROP CONSTRAINT IF EXISTS checkins_operator_user_fkey;
ALTER TABLE public.checkins ADD CONSTRAINT checkins_operator_user_fkey
    FOREIGN KEY (operator_user) REFERENCES public.users_profile(user_id);


-- 3. DASHBOARD METRICS (RPC)
CREATE OR REPLACE FUNCTION public.get_staff_dashboard(p_event_id uuid)
RETURNS jsonb AS $$
DECLARE
  v_role text;
  v_uid uuid;
  v_result jsonb;
BEGIN
  v_uid := auth.uid();
  v_role := coalesce(
    auth.jwt() -> 'app_metadata' ->> 'role',
    auth.jwt() -> 'user_metadata' ->> 'role',
    'rrpp'
  );

  IF v_role = 'admin' OR v_role = 'door' THEN
    v_result := jsonb_build_object(
      'total_sold', (SELECT count(*) FROM public.tickets WHERE event_id = p_event_id),
      'scanned', (SELECT count(*) FROM public.tickets WHERE event_id = p_event_id AND status = 'used'),
      'valid', (SELECT count(*) FROM public.tickets WHERE event_id = p_event_id AND status = 'valid'),
      'revenue', (SELECT coalesce(sum(price), 0) FROM public.tickets WHERE event_id = p_event_id),
      'standard_created', (SELECT count(t2.id) FROM public.tickets t2 JOIN public.ticket_types tt ON t2.event_id = tt.event_id AND t2.type = tt.name WHERE t2.event_id = p_event_id AND tt.category = 'standard'),
      'standard_entered', (SELECT count(t2.id) FROM public.tickets t2 JOIN public.ticket_types tt ON t2.event_id = tt.event_id AND t2.type = tt.name WHERE t2.event_id = p_event_id AND tt.category = 'standard' AND t2.status = 'used'),
      'staff_created', (SELECT count(t2.id) FROM public.tickets t2 JOIN public.ticket_types tt ON t2.event_id = tt.event_id AND t2.type = tt.name WHERE t2.event_id = p_event_id AND tt.category = 'staff'),
      'staff_entered', (SELECT count(t2.id) FROM public.tickets t2 JOIN public.ticket_types tt ON t2.event_id = tt.event_id AND t2.type = tt.name WHERE t2.event_id = p_event_id AND tt.category = 'staff' AND t2.status = 'used'),
      'guest_created', (SELECT count(t2.id) FROM public.tickets t2 JOIN public.ticket_types tt ON t2.event_id = tt.event_id AND t2.type = tt.name WHERE t2.event_id = p_event_id AND tt.category = 'guest'),
      'guest_entered', (SELECT count(t2.id) FROM public.tickets t2 JOIN public.ticket_types tt ON t2.event_id = tt.event_id AND t2.type = tt.name WHERE t2.event_id = p_event_id AND tt.category = 'guest' AND t2.status = 'used')
    );
  ELSIF v_role = 'rrpp' THEN
    v_result := jsonb_build_object(
      'my_sales', (SELECT count(*) FROM public.tickets WHERE event_id = p_event_id AND created_by = v_uid),
      'my_revenue', (SELECT coalesce(sum(price), 0) FROM public.tickets WHERE event_id = p_event_id AND created_by = v_uid),
      'my_invitations_used', (SELECT count(*) FROM public.tickets WHERE event_id = p_event_id AND created_by = v_uid AND (type = 'invitation' OR type = 'invitado') AND status = 'used'),
      'my_quota', coalesce((SELECT quota_limit FROM public.event_staff WHERE event_id = p_event_id AND user_id = v_uid), 0)
    );
  END IF;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 4. STATISTICS RPC (ADMIN ONLY)
CREATE OR REPLACE FUNCTION public.get_event_statistics(p_event_id uuid)
RETURNS jsonb AS $$
DECLARE
  v_role text;
  v_stats jsonb;
BEGIN
  v_role := auth.jwt() -> 'app_metadata' ->> 'role';
  IF v_role != 'admin' THEN
    RAISE EXCEPTION 'Unauthorized: Statistics only available for Admin role';
  END IF;

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
        FROM public.tickets t LEFT JOIN auth.users u ON t.created_by = u.id LEFT JOIN public.users_profile up ON u.id = up.user_id
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
