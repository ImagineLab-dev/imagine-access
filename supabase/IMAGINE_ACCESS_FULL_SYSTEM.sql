-- ==============================================================================
-- IMAGINE ACCESS: THE INDESTRUCTIBLE MASTER SCRIPT (v1.0)
-- ==============================================================================
-- Purpose: 100% System Readiness. Tables, RLS, Triggers, RPCs, and Realtime.
-- Run this once to clean up and unify the entire backend.
-- ==============================================================================

BEGIN;

-- 1. BASE SYSTEM & EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. CORE INFRASTRUCTURE (Tables)

-- Profiles
CREATE TABLE IF NOT EXISTS public.users_profile (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
    display_name TEXT,
    role TEXT DEFAULT 'rrpp' CHECK (role IN ('admin', 'rrpp', 'door')),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Events
CREATE TABLE IF NOT EXISTS public.events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    slug TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    date TIMESTAMPTZ NOT NULL,
    venue TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Ticket Types (With Colors & Expiration)
CREATE TABLE IF NOT EXISTS public.ticket_types (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID REFERENCES public.events(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    category TEXT DEFAULT 'standard' CHECK (category IN ('standard', 'guest', 'staff', 'invitation')),
    price NUMERIC DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    color TEXT DEFAULT '#4F46E5',
    valid_until TIMESTAMPTZ DEFAULT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(event_id, name)
);

-- Tickets (With Scanned Status & Idempotency)
CREATE TABLE IF NOT EXISTS public.tickets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID REFERENCES public.events(id) ON DELETE CASCADE NOT NULL,
    type TEXT NOT NULL, 
    price NUMERIC DEFAULT 0,
    buyer_name TEXT NOT NULL,
    buyer_email TEXT NOT NULL,
    buyer_phone TEXT,
    buyer_doc TEXT,
    status TEXT DEFAULT 'valid' CHECK (status IN ('valid', 'used', 'void')),
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT now(),
    scanned_at TIMESTAMPTZ DEFAULT NULL,
    email_sent_at TIMESTAMPTZ,
    pdf_url TEXT,
    qr_token TEXT UNIQUE,
    request_id UUID UNIQUE -- Idempotency protection
);

-- Checkins (Entries)
CREATE TABLE IF NOT EXISTS public.checkins (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ticket_id UUID REFERENCES public.tickets(id) ON DELETE CASCADE NOT NULL,
    event_id UUID REFERENCES public.events(id) ON DELETE CASCADE NOT NULL,
    scanned_at TIMESTAMPTZ DEFAULT now(),
    device_id TEXT,
    operator_user UUID REFERENCES auth.users(id),
    result TEXT DEFAULT 'allowed',
    notes TEXT,
    method TEXT DEFAULT 'qr',
    request_id UUID UNIQUE -- Idempotency protection
);

-- Staff assignments
CREATE TABLE IF NOT EXISTS public.event_staff (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID REFERENCES public.events(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('rrpp', 'door', 'admin')),
    
    -- Professional Separate Quotas
    quota_standard INT DEFAULT 0,
    quota_standard_used INT DEFAULT 0,
    quota_guest INT DEFAULT 0,
    quota_guest_used INT DEFAULT 0,
    quota_invitation INT DEFAULT 0,
    quota_invitation_used INT DEFAULT 0,
    
    assigned_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (event_id, user_id)
);

-- Devices (Door Access)
CREATE TABLE IF NOT EXISTS public.devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id TEXT, -- For legacy support or explicit ID
    pin TEXT NOT NULL,
    alias TEXT,
    enabled BOOLEAN DEFAULT true,
    last_active_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- FORCE SCHEMA SYNC (In case table exists but misses columns)
DO $$
BEGIN
    BEGIN ALTER TABLE public.devices ADD COLUMN IF NOT EXISTS device_id TEXT; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER TABLE public.devices ADD COLUMN IF NOT EXISTS pin TEXT; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER TABLE public.devices ADD COLUMN IF NOT EXISTS alias TEXT; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER TABLE public.devices ADD COLUMN IF NOT EXISTS enabled BOOLEAN DEFAULT true; EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;

-- Traceability Indexes
CREATE INDEX IF NOT EXISTS idx_tickets_request_id ON public.tickets(request_id);
CREATE INDEX IF NOT EXISTS idx_checkins_request_id ON public.checkins(request_id);
CREATE INDEX IF NOT EXISTS idx_tickets_event_id ON public.tickets(event_id);
CREATE INDEX IF NOT EXISTS idx_checkins_event_id ON public.checkins(event_id);


-- 3. SECURITY & PRIVACY (RLS)
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checkins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users_profile ENABLE ROW LEVEL SECURITY;

-- CLEANUP OLD POLICIES (All variations)
DROP POLICY IF EXISTS "Public read events" ON public.events;
DROP POLICY IF EXISTS "Public Events Read" ON public.events;
DROP POLICY IF EXISTS "Public read types" ON public.ticket_types;
DROP POLICY IF EXISTS "Public Types Read" ON public.ticket_types;
DROP POLICY IF EXISTS "Authenticated read tickets" ON public.tickets;
DROP POLICY IF EXISTS "Read tickets" ON public.tickets;
DROP POLICY IF EXISTS "Read tickets scoped" ON public.tickets;
DROP POLICY IF EXISTS "Strict Ticket Access" ON public.tickets;
DROP POLICY IF EXISTS "Insert tickets" ON public.tickets;
DROP POLICY IF EXISTS "Profile self-view" ON public.users_profile;
DROP POLICY IF EXISTS "Profile self-access" ON public.users_profile;

-- NEW DROPS (To ensure idempotent runs)
DROP POLICY IF EXISTS "Read own staff assignments" ON public.event_staff;
DROP POLICY IF EXISTS "Staff read checkins" ON public.checkins;

-- CREATE ROBUST POLICIES
CREATE POLICY "Public Events Read" ON public.events FOR SELECT USING (true);
CREATE POLICY "Public Types Read" ON public.ticket_types FOR SELECT USING (true);

CREATE POLICY "Strict Ticket Access" ON public.tickets
FOR SELECT USING (
  (auth.jwt() -> 'app_metadata' ->> 'role' = 'admin') OR
  ((auth.jwt() -> 'app_metadata' ->> 'role' = 'rrpp') AND (created_by = auth.uid())) OR
  ((auth.jwt() -> 'app_metadata' ->> 'role' = 'door') AND (event_id IN (SELECT event_id FROM public.event_staff WHERE user_id = auth.uid())))
);

CREATE POLICY "Insert tickets" ON public.tickets FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Profile self-access" ON public.users_profile FOR ALL USING (auth.uid() = user_id OR auth.jwt() -> 'app_metadata' ->> 'role' = 'admin');


-- Staff & Checkins Policies
CREATE POLICY "Read own staff assignments" ON public.event_staff 
FOR SELECT USING (auth.uid() = user_id OR auth.jwt() -> 'app_metadata' ->> 'role' = 'admin');

CREATE POLICY "Staff read checkins" ON public.checkins 
FOR SELECT USING (auth.role() = 'authenticated');

-- 4. REAL-TIME SYNCHRONIZATION
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        CREATE PUBLICATION supabase_realtime;
    END IF;
END $$;

DO $$
BEGIN
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.checkins; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.tickets; EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;

ALTER TABLE public.checkins REPLICA IDENTITY FULL;
ALTER TABLE public.tickets REPLICA IDENTITY FULL;


-- 5. BUSINESS LOGIC (RPCs & Triggers)

-- Role Sync Trigger
CREATE OR REPLACE FUNCTION public.handle_user_role_update() 
RETURNS TRIGGER AS $$
BEGIN
    UPDATE auth.users SET raw_app_meta_data = 
        COALESCE(raw_app_meta_data, '{}'::jsonb) || JSONB_BUILD_OBJECT('role', NEW.role)
    WHERE id = NEW.user_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_role_change ON public.users_profile;
CREATE TRIGGER on_role_change AFTER INSERT OR UPDATE OF role ON public.users_profile
FOR EACH ROW EXECUTE PROCEDURE public.handle_user_role_update();

-- Quota Counter Trigger
CREATE OR REPLACE FUNCTION public.increment_quota_usage()
RETURNS TRIGGER AS $$
DECLARE v_category TEXT;
BEGIN
    SELECT category INTO v_category FROM public.ticket_types 
    WHERE event_id = NEW.event_id AND name = NEW.type;
    IF v_category = 'guest' THEN
        UPDATE public.event_staff SET quota_guest_used = quota_guest_used + 1 WHERE event_id = NEW.event_id AND user_id = NEW.created_by;
    ELSIF v_category = 'invitation' THEN
        UPDATE public.event_staff SET quota_invitation_used = quota_invitation_used + 1 WHERE event_id = NEW.event_id AND user_id = NEW.created_by;
    ELSE
        UPDATE public.event_staff SET quota_standard_used = quota_standard_used + 1 WHERE event_id = NEW.event_id AND user_id = NEW.created_by;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_ticket_created_quota ON public.tickets;
CREATE TRIGGER on_ticket_created_quota AFTER INSERT ON public.tickets
FOR EACH ROW EXECUTE FUNCTION public.increment_quota_usage();

-- Ticket Status Sync Trigger (Automated robustness)
CREATE OR REPLACE FUNCTION public.handle_checkin_status_sync()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.result = 'allowed' THEN
        UPDATE public.tickets 
        SET status = 'used', 
            scanned_at = NEW.scanned_at
        WHERE id = NEW.ticket_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_checkin_status_sync ON public.checkins;
CREATE TRIGGER on_checkin_status_sync AFTER INSERT ON public.checkins
FOR EACH ROW EXECUTE FUNCTION public.handle_checkin_status_sync();

-- DASHBOARD RPC
CREATE OR REPLACE FUNCTION public.get_staff_dashboard(p_event_id uuid)
RETURNS jsonb AS $$
DECLARE
  v_role text; v_uid uuid; v_result jsonb;
BEGIN
  v_uid := auth.uid(); v_role := COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', 'rrpp');
  IF v_role = 'admin' OR v_role = 'door' THEN
    v_result := jsonb_build_object(
      'total_sold', (SELECT COUNT(*) FROM public.tickets WHERE event_id = p_event_id),
      -- Robust 'scanned' count using checkins table
      'scanned', (SELECT COUNT(DISTINCT ticket_id) FROM public.checkins WHERE event_id = p_event_id AND result = 'allowed'),
      
      -- Manual Check-ins (Non-QR)
      'scanned_manual', (SELECT COUNT(DISTINCT ticket_id) FROM public.checkins WHERE event_id = p_event_id AND result = 'allowed' AND method <> 'qr'),

      -- Robust 'valid' count: Status is valid/null AND no successful checkin
      'valid', (
        SELECT COUNT(*) FROM public.tickets 
        WHERE event_id = p_event_id 
        AND (status IS NULL OR LOWER(status) = 'valid')
        AND id NOT IN (SELECT ticket_id FROM public.checkins WHERE event_id = p_event_id AND result = 'allowed')
      ),
      'revenue', (SELECT COALESCE(SUM(price), 0) FROM public.tickets WHERE event_id = p_event_id),
      
      -- Granular metrics
      'standard_created', (SELECT COUNT(t.id) FROM public.tickets t JOIN public.ticket_types tt ON t.type = tt.name AND t.event_id = tt.event_id WHERE t.event_id = p_event_id AND tt.category = 'standard'),
      'standard_entered', (SELECT COUNT(DISTINCT t.id) FROM public.tickets t JOIN public.ticket_types tt ON t.type = tt.name AND t.event_id = tt.event_id JOIN public.checkins c ON t.id = c.ticket_id WHERE t.event_id = p_event_id AND tt.category = 'standard' AND c.result = 'allowed'),
      
      'staff_created', (SELECT COUNT(t.id) FROM public.tickets t JOIN public.ticket_types tt ON t.type = tt.name AND t.event_id = tt.event_id WHERE t.event_id = p_event_id AND tt.category = 'staff'),
      'staff_entered', (SELECT COUNT(DISTINCT t.id) FROM public.tickets t JOIN public.ticket_types tt ON t.type = tt.name AND t.event_id = tt.event_id JOIN public.checkins c ON t.id = c.ticket_id WHERE t.event_id = p_event_id AND tt.category = 'staff' AND c.result = 'allowed'),
      
      'guest_created', (SELECT COUNT(t.id) FROM public.tickets t JOIN public.ticket_types tt ON t.type = tt.name AND t.event_id = tt.event_id WHERE t.event_id = p_event_id AND tt.category = 'guest'),
      'guest_entered', (SELECT COUNT(DISTINCT t.id) FROM public.tickets t JOIN public.ticket_types tt ON t.type = tt.name AND t.event_id = tt.event_id JOIN public.checkins c ON t.id = c.ticket_id WHERE t.event_id = p_event_id AND tt.category = 'guest' AND c.result = 'allowed')
    );
  ELSIF v_role = 'rrpp' THEN
    v_result := (
        SELECT jsonb_build_object(
          -- CARD 1: VENTAS (Paid tickets)
          'paid_tickets_count', (SELECT COUNT(*) FROM public.tickets t JOIN public.ticket_types tt ON t.type = tt.name AND t.event_id = tt.event_id WHERE t.event_id = p_event_id AND t.created_by = v_uid AND t.price > 0),
          'paid_tickets_today', (SELECT COUNT(*) FROM public.tickets t JOIN public.ticket_types tt ON t.type = tt.name AND t.event_id = tt.event_id WHERE t.event_id = p_event_id AND t.created_by = v_uid AND t.price > 0 AND t.created_at >= CURRENT_DATE),
          
          -- CARD 2: TOTAL EMITIDOS (Paid + Invites)
          'total_issued', (SELECT COUNT(*) FROM public.tickets WHERE event_id = p_event_id AND created_by = v_uid),
          'invitations_count', (SELECT COUNT(*) FROM public.tickets t JOIN public.ticket_types tt ON t.type = tt.name AND t.event_id = tt.event_id WHERE t.event_id = p_event_id AND t.created_by = v_uid AND t.price = 0),
          
          -- CARD 3: INVITACIONES NORMAL (Standard Quota)
          'quota_standard', es.quota_standard,
          'quota_standard_used', es.quota_standard_used,
          'remaining_standard', (es.quota_standard - es.quota_standard_used),
          
          -- CARD 4: INVITACIONES GUEST (Guest/VIP Quota)
          'quota_guest', es.quota_guest,
          'quota_guest_used', es.quota_guest_used,
          'remaining_guest', (es.quota_guest - es.quota_guest_used),

          -- CARD 5: INGRESARON (Validated)
          'total_scanned', (SELECT COUNT(DISTINCT t.id) FROM public.tickets t JOIN public.checkins c ON t.id = c.ticket_id WHERE t.event_id = p_event_id AND t.created_by = v_uid AND c.result = 'allowed'),
          
          'my_revenue', (SELECT COALESCE(SUM(price), 0) FROM public.tickets WHERE event_id = p_event_id AND created_by = v_uid)
        )
        FROM public.event_staff es 
        WHERE es.event_id = p_event_id AND es.user_id = v_uid
    );
  END IF;
  RETURN COALESCE(v_result, '{"my_sales":0, "my_revenue":0}'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- UNIFIED SEARCH RPC (Phone & Doc)
CREATE OR REPLACE FUNCTION public.search_tickets_unified(
    p_query text,
    p_type text,
    p_event_id uuid,
    p_device_id text DEFAULT NULL::text,
    p_device_pin text DEFAULT NULL::text
)
RETURNS jsonb AS $$
DECLARE
  v_is_authenticated boolean := false;
  v_results jsonb;
BEGIN
  -- Authenticate: Check for User Session OR Valid Device
  -- Authenticate: Check for User Session OR Valid Device
  -- NOTE: We use 'device_id' (TEXT) which is the unique string ID, not 'id' (UUID)
  IF auth.uid() IS NOT NULL OR EXISTS (SELECT 1 FROM public.devices d WHERE d.device_id = p_device_id AND d.pin = p_device_pin AND d.enabled = true) THEN
    v_is_authenticated := true;
  END IF;
  
  -- Return empty if not authenticated
  IF v_is_authenticated IS NOT true THEN 
    RETURN '[]'::jsonb; 
  END IF;

  -- Search Logic
  IF p_type = 'doc' THEN
    SELECT jsonb_agg(
      jsonb_build_object(
        'id', tic.id,
        'event_id', tic.event_id,
        'buyer_name', tic.buyer_name,
        'buyer_doc', tic.buyer_doc,
        'buyer_phone', tic.buyer_phone,
        'type', tic.type,
        'status', tic.status,
        'price', tic.price,
        'qr_token', tic.qr_token,
        'creator_name', up.display_name
      )
    ) INTO v_results 
    FROM public.tickets tic 
    LEFT JOIN public.users_profile up ON tic.created_by = up.user_id 
    WHERE tic.event_id = p_event_id 
    AND (
        tic.buyer_doc ILIKE '%' || p_query || '%' 
        OR 
        regexp_replace(tic.buyer_doc, '\D', '', 'g') = regexp_replace(p_query, '\D', '', 'g')
    );
  ELSE
    SELECT jsonb_agg(
      jsonb_build_object(
        'id', tic.id,
        'event_id', tic.event_id,
        'buyer_name', tic.buyer_name,
        'buyer_doc', tic.buyer_doc,
        'buyer_phone', tic.buyer_phone,
        'type', tic.type,
        'status', tic.status,
        'price', tic.price,
        'qr_token', tic.qr_token,
        'creator_name', up.display_name
      )
    ) INTO v_results 
    FROM public.tickets tic 
    LEFT JOIN public.users_profile up ON tic.created_by = up.user_id 
    WHERE tic.event_id = p_event_id 
    AND (
        tic.buyer_phone ILIKE '%' || p_query || '%' 
        OR 
        regexp_replace(tic.buyer_phone, '\D', '', 'g') = regexp_replace(p_query, '\D', '', 'g')
    );
  END IF;

  RETURN COALESCE(v_results, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STATS RPC (Graphs)
CREATE OR REPLACE FUNCTION public.get_event_statistics(p_event_id uuid)
RETURNS jsonb AS $$
DECLARE v_stats jsonb;
BEGIN
  SELECT jsonb_build_object(
    'attendance_by_hour', (SELECT jsonb_agg(h) FROM (SELECT to_char(date_trunc('hour', scanned_at), 'HH24:00') AS hour, count(*) AS count FROM public.checkins WHERE event_id = p_event_id GROUP BY 1 ORDER BY 1) h),
    'rrpp_performance', (SELECT jsonb_agg(p) FROM (SELECT up.display_name AS name, t.type, count(*) AS count FROM public.tickets t LEFT JOIN public.users_profile up ON t.created_by = up.user_id WHERE t.event_id = p_event_id GROUP BY 1, 2 ORDER BY 3 DESC) p),
    'sales_timeline', (SELECT jsonb_agg(s) FROM (SELECT created_at::date AS day, count(*) AS count, sum(price) AS revenue FROM public.tickets WHERE event_id = p_event_id GROUP BY 1 ORDER BY 1) s)
  ) INTO v_stats;
  RETURN v_stats;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- DEVICE RPC (Smart Auth)
CREATE OR REPLACE FUNCTION public.get_device_tickets(
    p_device_id text,
    p_device_pin text
)
RETURNS jsonb AS $$
DECLARE
  v_is_authenticated boolean := false;
  v_result jsonb;
  v_sql text;
  v_count int;
BEGIN
  -- 1. Dynamic Authentication
  -- We build a query that checks 'id::text' AND 'device_id' (if it exists)
  -- This handles both UUIDs and Friendly IDs without throwing errors.
  
  v_sql := 'SELECT count(*) FROM public.devices WHERE enabled = true AND pin = $1 AND (cast(id as text) = $2';
  
  -- Check if 'device_id' column exists to include it in the OR condition
  IF EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'devices' AND column_name = 'device_id'
  ) THEN
      v_sql := v_sql || ' OR device_id = $2';
  END IF;
  
  v_sql := v_sql || ')';
  
  -- Execute the dynamic query
  EXECUTE v_sql INTO v_count USING p_device_pin, p_device_id;
  
  IF v_count > 0 THEN
      v_is_authenticated := true;
  END IF;

  -- 2. Return Empty if Auth Fails
  IF v_is_authenticated IS NOT TRUE THEN
    RETURN '[]'::jsonb;
  END IF;

  -- 3. Fetch Tickets (All tickets)
  SELECT jsonb_agg(
    to_jsonb(t) || 
    jsonb_build_object(
      'events', jsonb_build_object('name', e.name),
      'users_profile', CASE WHEN up.user_id IS NOT NULL THEN jsonb_build_object('display_name', up.display_name) ELSE null END,
      'checkins', COALESCE((
          SELECT jsonb_agg(jsonb_build_object('id', c.id))
          FROM public.checkins c
          WHERE c.ticket_id = t.id
      ), '[]'::jsonb)
    )
  ) INTO v_result
  FROM public.tickets t
  LEFT JOIN public.events e ON t.event_id = e.id
  LEFT JOIN public.users_profile up ON t.created_by = up.user_id
  ORDER BY t.created_at DESC;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ROBUST TICKET FETCHING (Bypasses RLS complexity)
CREATE OR REPLACE FUNCTION public.get_authorized_tickets()
RETURNS jsonb AS $$
DECLARE
  v_uid uuid;
  v_results jsonb;
BEGIN
  v_uid := auth.uid();
  
  -- Logic:
  -- Admin: All tickets
  -- Door: Tickets for events where they are assigned (role 'door' or 'admin')
  -- RRPP: Tickets they created

  SELECT jsonb_agg(
      to_jsonb(t) || 
      jsonb_build_object(
        'events', jsonb_build_object('name', e.name),
        'users_profile', CASE WHEN up.user_id IS NOT NULL THEN jsonb_build_object('display_name', up.display_name) ELSE null END,
        'checkins', COALESCE((
            SELECT jsonb_agg(jsonb_build_object('id', c.id))
            FROM public.checkins c
            WHERE c.ticket_id = t.id
        ), '[]'::jsonb)
      )
  ) INTO v_results
  FROM public.tickets t
  LEFT JOIN public.events e ON t.event_id = e.id
  LEFT JOIN public.users_profile up ON t.created_by = up.user_id
  WHERE 
    -- 1. ADMIN OR DOOR (Global Access/Trust)
    -- This ensures any user with the 'door' role can scan/view tickets immediately
    (EXISTS (SELECT 1 FROM public.users_profile WHERE user_id = v_uid AND (role = 'admin' OR role = 'door')))
    OR
    -- 2. STAFF ASSIGNMENT (Fallback for specific assignments if role is just 'rrpp')
    (t.event_id IN (SELECT event_id FROM public.event_staff WHERE user_id = v_uid))
    OR
    -- 3. RRPP (Creator Access)
    (t.created_by = v_uid);

  RETURN COALESCE(v_results, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
