-- =============================================================================
-- ONE SHOT MULTITENANT SETUP (Imagine Access)
-- Run this single script in Supabase SQL Editor
-- Idempotent: safe to re-run
-- =============================================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- -----------------------------------------------------------------------------
-- 1) SCHEMA HARDENING
-- -----------------------------------------------------------------------------
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS scanned_at TIMESTAMPTZ;
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'valid';
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS request_id UUID;
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS email_sent_at TIMESTAMPTZ;
ALTER TABLE public.checkins ADD COLUMN IF NOT EXISTS request_id UUID;

ALTER TABLE public.ticket_types ADD COLUMN IF NOT EXISTS valid_until TIMESTAMPTZ;
ALTER TABLE public.ticket_types ADD COLUMN IF NOT EXISTS color TEXT DEFAULT '#4F46E5';
ALTER TABLE public.ticket_types ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'standard';

CREATE TABLE IF NOT EXISTS public.event_staff (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID REFERENCES public.events(id) NOT NULL,
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('rrpp', 'door', 'admin')),
    quota_limit INT DEFAULT 0,
    quota_used INT DEFAULT 0,
    quota_standard INT DEFAULT 0,
    quota_standard_used INT DEFAULT 0,
    quota_guest INT DEFAULT 0,
    quota_guest_used INT DEFAULT 0,
    quota_invitation INT DEFAULT 0,
    quota_invitation_used INT DEFAULT 0,
    assigned_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (event_id, user_id)
);

ALTER TABLE public.event_staff ADD COLUMN IF NOT EXISTS quota_limit INT DEFAULT 0;
ALTER TABLE public.event_staff ADD COLUMN IF NOT EXISTS quota_used INT DEFAULT 0;
ALTER TABLE public.event_staff ADD COLUMN IF NOT EXISTS quota_standard INT DEFAULT 0;
ALTER TABLE public.event_staff ADD COLUMN IF NOT EXISTS quota_standard_used INT DEFAULT 0;
ALTER TABLE public.event_staff ADD COLUMN IF NOT EXISTS quota_guest INT DEFAULT 0;
ALTER TABLE public.event_staff ADD COLUMN IF NOT EXISTS quota_guest_used INT DEFAULT 0;
ALTER TABLE public.event_staff ADD COLUMN IF NOT EXISTS quota_invitation INT DEFAULT 0;
ALTER TABLE public.event_staff ADD COLUMN IF NOT EXISTS quota_invitation_used INT DEFAULT 0;

CREATE TABLE IF NOT EXISTS public.organizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    slug TEXT UNIQUE NOT NULL,
    owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.users_profile ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES public.organizations(id) ON DELETE SET NULL;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;
ALTER TABLE public.devices ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;
ALTER TABLE public.devices ADD COLUMN IF NOT EXISTS pin TEXT;
ALTER TABLE public.devices ADD COLUMN IF NOT EXISTS pin_hash TEXT;
ALTER TABLE public.devices ADD COLUMN IF NOT EXISTS pin_salt TEXT;

DO $$
BEGIN
  BEGIN
    ALTER TABLE public.devices ALTER COLUMN pin DROP NOT NULL;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;
END $$;

CREATE INDEX IF NOT EXISTS idx_users_profile_org ON public.users_profile(organization_id);
CREATE INDEX IF NOT EXISTS idx_events_org ON public.events(organization_id);
CREATE INDEX IF NOT EXISTS idx_devices_org ON public.devices(organization_id);
CREATE INDEX IF NOT EXISTS idx_tickets_request_id ON public.tickets(request_id);

-- -----------------------------------------------------------------------------
-- 2) BACKFILL ORGANIZATIONS (legacy data)
-- -----------------------------------------------------------------------------
INSERT INTO public.organizations (name, slug, owner_id)
SELECT DISTINCT ON (e.created_by)
    COALESCE(u.raw_user_meta_data->>'display_name', u.email) || ' Organization',
    lower(regexp_replace(COALESCE(u.raw_user_meta_data->>'display_name', split_part(u.email, '@', 1)), '[^a-zA-Z0-9]+', '-', 'g')) || '-' || substr(md5(random()::text), 1, 6),
    e.created_by
FROM public.events e
JOIN auth.users u ON e.created_by = u.id
WHERE e.created_by IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM public.organizations o WHERE o.owner_id = e.created_by
);

UPDATE public.users_profile up
SET organization_id = o.id,
    role = COALESCE(up.role, 'admin')
FROM public.organizations o
WHERE up.user_id = o.owner_id
AND up.organization_id IS NULL;

UPDATE public.events e
SET organization_id = up.organization_id
FROM public.users_profile up
WHERE e.created_by = up.user_id
AND e.organization_id IS NULL;

-- -----------------------------------------------------------------------------
-- 3) RLS POLICIES (strict org isolation)
-- -----------------------------------------------------------------------------
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users_profile ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_staff ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users see own organization" ON public.organizations;
CREATE POLICY "Users see own organization" ON public.organizations
FOR ALL USING (
  owner_id = auth.uid()
  OR id IN (SELECT organization_id FROM public.users_profile WHERE user_id = auth.uid())
);

DROP POLICY IF EXISTS "Public Events Read" ON public.events;
DROP POLICY IF EXISTS "Organization Events Read" ON public.events;
CREATE POLICY "Organization Events Read" ON public.events
FOR SELECT USING (
  organization_id IN (SELECT organization_id FROM public.users_profile WHERE user_id = auth.uid())
  OR created_by = auth.uid()
);

DROP POLICY IF EXISTS "Organization Events Insert" ON public.events;
CREATE POLICY "Organization Events Insert" ON public.events
FOR INSERT WITH CHECK (
  COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', auth.jwt() -> 'user_metadata' ->> 'role', 'rrpp') = 'admin'
  AND (
    organization_id IN (SELECT organization_id FROM public.users_profile WHERE user_id = auth.uid())
    OR created_by = auth.uid()
  )
);

DROP POLICY IF EXISTS "Organization Events Update" ON public.events;
CREATE POLICY "Organization Events Update" ON public.events
FOR UPDATE USING (
  COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', auth.jwt() -> 'user_metadata' ->> 'role', 'rrpp') = 'admin'
  AND (
    organization_id IN (SELECT organization_id FROM public.users_profile WHERE user_id = auth.uid())
    OR created_by = auth.uid()
  )
);

DROP POLICY IF EXISTS "Organization Events Delete" ON public.events;
CREATE POLICY "Organization Events Delete" ON public.events
FOR DELETE USING (
  COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', auth.jwt() -> 'user_metadata' ->> 'role', 'rrpp') = 'admin'
  AND (
    organization_id IN (SELECT organization_id FROM public.users_profile WHERE user_id = auth.uid())
    OR created_by = auth.uid()
  )
);

DROP POLICY IF EXISTS "Organization Types Read" ON public.ticket_types;
CREATE POLICY "Organization Types Read" ON public.ticket_types
FOR SELECT USING (
  event_id IN (
    SELECT id FROM public.events
    WHERE organization_id IN (SELECT organization_id FROM public.users_profile WHERE user_id = auth.uid())
    OR created_by = auth.uid()
  )
);

DROP POLICY IF EXISTS "Organization Types Write" ON public.ticket_types;
CREATE POLICY "Organization Types Write" ON public.ticket_types
FOR ALL USING (
  COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', auth.jwt() -> 'user_metadata' ->> 'role', 'rrpp') = 'admin'
  AND event_id IN (
    SELECT id FROM public.events
    WHERE organization_id IN (SELECT organization_id FROM public.users_profile WHERE user_id = auth.uid())
       OR created_by = auth.uid()
  )
)
WITH CHECK (
  event_id IN (
    SELECT id FROM public.events
    WHERE organization_id IN (SELECT organization_id FROM public.users_profile WHERE user_id = auth.uid())
       OR created_by = auth.uid()
  )
);

DROP POLICY IF EXISTS "Organization Tickets Read" ON public.tickets;
CREATE POLICY "Organization Tickets Read" ON public.tickets
FOR SELECT USING (
  event_id IN (
    SELECT id FROM public.events
    WHERE organization_id IN (SELECT organization_id FROM public.users_profile WHERE user_id = auth.uid())
    OR created_by = auth.uid()
  )
  OR created_by = auth.uid()
);

DROP POLICY IF EXISTS "Organization Devices Access" ON public.devices;
CREATE POLICY "Organization Devices Access" ON public.devices
FOR ALL USING (
  organization_id IN (SELECT organization_id FROM public.users_profile WHERE user_id = auth.uid())
);

DROP POLICY IF EXISTS "Users Profile Read" ON public.users_profile;
CREATE POLICY "Users Profile Read" ON public.users_profile
FOR SELECT USING (
  user_id = auth.uid()
  OR organization_id::text = COALESCE(
    auth.jwt() -> 'app_metadata' ->> 'organization_id',
    auth.jwt() -> 'user_metadata' ->> 'organization_id'
  )
);

DROP POLICY IF EXISTS "Users Profile Admin Insert" ON public.users_profile;
CREATE POLICY "Users Profile Admin Insert" ON public.users_profile
FOR INSERT WITH CHECK (
  COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', auth.jwt() -> 'user_metadata' ->> 'role', 'rrpp') = 'admin'
  AND organization_id::text = COALESCE(
    auth.jwt() -> 'app_metadata' ->> 'organization_id',
    auth.jwt() -> 'user_metadata' ->> 'organization_id'
  )
);

DROP POLICY IF EXISTS "Users Profile Admin Update" ON public.users_profile;
CREATE POLICY "Users Profile Admin Update" ON public.users_profile
FOR UPDATE USING (
  COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', auth.jwt() -> 'user_metadata' ->> 'role', 'rrpp') = 'admin'
  AND organization_id::text = COALESCE(
    auth.jwt() -> 'app_metadata' ->> 'organization_id',
    auth.jwt() -> 'user_metadata' ->> 'organization_id'
  )
)
WITH CHECK (
  organization_id::text = COALESCE(
    auth.jwt() -> 'app_metadata' ->> 'organization_id',
    auth.jwt() -> 'user_metadata' ->> 'organization_id'
  )
);

DROP POLICY IF EXISTS "Users Profile Admin Delete" ON public.users_profile;
CREATE POLICY "Users Profile Admin Delete" ON public.users_profile
FOR DELETE USING (
  COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', auth.jwt() -> 'user_metadata' ->> 'role', 'rrpp') = 'admin'
  AND organization_id::text = COALESCE(
    auth.jwt() -> 'app_metadata' ->> 'organization_id',
    auth.jwt() -> 'user_metadata' ->> 'organization_id'
  )
);

DROP POLICY IF EXISTS "Event Staff Read" ON public.event_staff;
CREATE POLICY "Event Staff Read" ON public.event_staff
FOR SELECT USING (
  user_id = auth.uid()
  OR event_id IN (
    SELECT e.id
    FROM public.events e
    WHERE e.organization_id::text = COALESCE(
      auth.jwt() -> 'app_metadata' ->> 'organization_id',
      auth.jwt() -> 'user_metadata' ->> 'organization_id'
    )
  )
);

DROP POLICY IF EXISTS "Event Staff Admin Write" ON public.event_staff;
CREATE POLICY "Event Staff Admin Write" ON public.event_staff
FOR ALL USING (
  COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', auth.jwt() -> 'user_metadata' ->> 'role', 'rrpp') = 'admin'
  AND event_id IN (
    SELECT e.id
    FROM public.events e
    WHERE e.organization_id::text = COALESCE(
      auth.jwt() -> 'app_metadata' ->> 'organization_id',
      auth.jwt() -> 'user_metadata' ->> 'organization_id'
    )
  )
)
WITH CHECK (
  event_id IN (
    SELECT e.id
    FROM public.events e
    WHERE e.organization_id::text = COALESCE(
      auth.jwt() -> 'app_metadata' ->> 'organization_id',
      auth.jwt() -> 'user_metadata' ->> 'organization_id'
    )
  )
);

-- -----------------------------------------------------------------------------
-- 4) REALTIME + FK TRACEABILITY
-- -----------------------------------------------------------------------------
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

ALTER TABLE public.tickets DROP CONSTRAINT IF EXISTS tickets_created_by_fkey;
ALTER TABLE public.tickets ADD CONSTRAINT tickets_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users_profile(user_id);

ALTER TABLE public.checkins DROP CONSTRAINT IF EXISTS checkins_operator_user_fkey;
ALTER TABLE public.checkins ADD CONSTRAINT checkins_operator_user_fkey FOREIGN KEY (operator_user) REFERENCES public.users_profile(user_id);

-- -----------------------------------------------------------------------------
-- 5) RPCs REQUIRED BY APP
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.increment_event_quota(p_event_id uuid, p_user_id uuid)
RETURNS boolean
AS $$
DECLARE
  v_limit int;
  v_used int;
BEGIN
  SELECT
    COALESCE(NULLIF(quota_invitation, 0), quota_limit, 0),
    COALESCE(quota_invitation_used, quota_used, 0)
  INTO v_limit, v_used
  FROM public.event_staff
  WHERE event_id = p_event_id AND user_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF v_used >= v_limit THEN
    RETURN false;
  END IF;

  UPDATE public.event_staff
  SET
    quota_invitation_used = COALESCE(quota_invitation_used, 0) + 1,
    quota_used = COALESCE(quota_used, 0) + 1
  WHERE event_id = p_event_id AND user_id = p_user_id;

  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.search_tickets_unified(
  p_query text,
  p_type text,
  p_event_id uuid,
  p_device_id text DEFAULT NULL,
  p_device_pin text DEFAULT NULL
)
RETURNS jsonb
AS $$
DECLARE
  v_uid uuid;
  v_is_authenticated boolean := false;
  v_device_org_id uuid;
  v_results jsonb := '[]'::jsonb;
  v_event_org_id uuid;
  v_user_org_id uuid;
BEGIN
  v_uid := auth.uid();

  IF v_uid IS NOT NULL THEN
    v_is_authenticated := true;
  ELSIF p_device_id IS NOT NULL AND p_device_pin IS NOT NULL THEN
    SELECT d.organization_id
      INTO v_device_org_id
    FROM public.devices d
    WHERE d.enabled = true
      AND (
        cast(d.id as text) = p_device_id
        OR (
          EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'devices' AND column_name = 'device_id'
          )
          AND d.device_id = p_device_id
        )
      )
      AND (
        (
          d.pin_hash IS NOT NULL
          AND d.pin_salt IS NOT NULL
          AND d.pin_hash = encode(digest(d.pin_salt || ':' || p_device_pin, 'sha256'), 'hex')
        )
        OR (d.pin_hash IS NULL AND d.pin = p_device_pin)
      )
    LIMIT 1;

    IF v_device_org_id IS NOT NULL THEN
      v_is_authenticated := true;
    END IF;
  END IF;

  IF v_is_authenticated IS NOT TRUE THEN
    RETURN jsonb_build_object('error', 'Unauthorized: No valid session or device credentials');
  END IF;

  IF p_type NOT IN ('doc', 'phone') THEN
    RETURN jsonb_build_object('error', 'Invalid search type. Use doc or phone');
  END IF;

  SELECT e.organization_id INTO v_event_org_id FROM public.events e WHERE e.id = p_event_id;
  IF NOT FOUND THEN RETURN '[]'::jsonb; END IF;

  IF v_uid IS NOT NULL THEN
    SELECT up.organization_id INTO v_user_org_id FROM public.users_profile up WHERE up.user_id = v_uid;
    IF v_event_org_id IS NOT NULL AND v_user_org_id IS DISTINCT FROM v_event_org_id THEN
      RETURN jsonb_build_object('error', 'Forbidden: event outside your organization');
    END IF;
  ELSIF v_device_org_id IS DISTINCT FROM v_event_org_id THEN
    RETURN jsonb_build_object('error', 'Forbidden: event outside your organization');
  END IF;

  IF p_type = 'doc' THEN
    SELECT jsonb_agg(t) INTO v_results
    FROM (
      SELECT tickets.*, events.name AS event_name
      FROM public.tickets
      JOIN public.events ON events.id = tickets.event_id
      WHERE tickets.event_id = p_event_id
        AND (tickets.buyer_doc ILIKE '%' || p_query || '%'
             OR regexp_replace(tickets.buyer_doc, '\D', '', 'g') = regexp_replace(p_query, '\D', '', 'g'))
    ) t;
  ELSE
    SELECT jsonb_agg(t) INTO v_results
    FROM (
      SELECT tickets.*, events.name AS event_name
      FROM public.tickets
      JOIN public.events ON events.id = tickets.event_id
      WHERE tickets.event_id = p_event_id
        AND (tickets.buyer_phone ILIKE '%' || p_query || '%'
             OR regexp_replace(tickets.buyer_phone, '\D', '', 'g') = regexp_replace(p_query, '\D', '', 'g'))
    ) t;
  END IF;

  RETURN COALESCE(v_results, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

CREATE OR REPLACE FUNCTION public.get_device_tickets(
    p_device_id text,
    p_device_pin text,
    p_event_id uuid DEFAULT NULL
)
RETURNS jsonb AS $$
DECLARE
  v_is_authenticated boolean := false;
  v_result jsonb := '[]'::jsonb;
  v_device_org_id uuid;
BEGIN
  SELECT d.organization_id
    INTO v_device_org_id
  FROM public.devices d
  WHERE d.enabled = true
    AND (
      cast(d.id as text) = p_device_id
      OR (
        EXISTS (
          SELECT 1
          FROM information_schema.columns
          WHERE table_schema = 'public'
            AND table_name = 'devices'
            AND column_name = 'device_id'
        )
        AND d.device_id = p_device_id
      )
    )
    AND (
      (
        d.pin_hash IS NOT NULL
        AND d.pin_salt IS NOT NULL
        AND d.pin_hash = encode(digest(d.pin_salt || ':' || p_device_pin, 'sha256'), 'hex')
      )
      OR (d.pin_hash IS NULL AND d.pin = p_device_pin)
    )
  LIMIT 1;

  IF v_device_org_id IS NOT NULL THEN
    v_is_authenticated := true;
  END IF;

  IF v_is_authenticated IS NOT TRUE THEN
    RETURN '[]'::jsonb;
  END IF;

  SELECT COALESCE(jsonb_agg(x.ticket_json), '[]'::jsonb)
  INTO v_result
  FROM (
    SELECT
      to_jsonb(t) ||
      jsonb_build_object(
        'events', jsonb_build_object('name', e.name),
        'users_profile', CASE WHEN up.user_id IS NOT NULL THEN jsonb_build_object('display_name', up.display_name) ELSE null END,
        'checkins', COALESCE((
            SELECT jsonb_agg(jsonb_build_object('id', c.id))
            FROM public.checkins c
            WHERE c.ticket_id = t.id
        ), '[]'::jsonb)
      ) AS ticket_json
    FROM public.tickets t
    LEFT JOIN public.events e ON t.event_id = e.id
    LEFT JOIN public.users_profile up ON t.created_by = up.user_id
    WHERE e.organization_id = v_device_org_id
      AND (p_event_id IS NULL OR t.event_id = p_event_id)
    ORDER BY t.created_at DESC
  ) x;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

CREATE OR REPLACE FUNCTION public.get_authorized_tickets()
RETURNS jsonb AS $$
DECLARE
  v_uid uuid;
  v_results jsonb;
BEGIN
  v_uid := auth.uid();

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
    (EXISTS (SELECT 1 FROM public.users_profile WHERE user_id = v_uid AND (role = 'admin' OR role = 'door')))
    OR
    (t.event_id IN (SELECT event_id FROM public.event_staff WHERE user_id = v_uid))
    OR
    (t.created_by = v_uid);

  RETURN COALESCE(v_results, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.manage_event_staff(
    p_event_id uuid,
    p_user_id uuid,
    p_role text,
    p_quota_standard int,
    p_quota_guest int,
    p_quota_invitation int
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_uid uuid;
    v_caller_role text;
    v_event_org_id uuid;
    v_target_user_org_id uuid;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
      RAISE EXCEPTION 'Unauthorized';
    END IF;

    v_caller_role := COALESCE(
      auth.jwt() -> 'app_metadata' ->> 'role',
      auth.jwt() -> 'user_metadata' ->> 'role',
      'rrpp'
    );

    IF v_caller_role <> 'admin' THEN
      RAISE EXCEPTION 'Forbidden: Admin role required';
    END IF;

    SELECT e.organization_id INTO v_event_org_id
    FROM public.events e
    WHERE e.id = p_event_id;

    IF v_event_org_id IS NULL THEN
      RAISE EXCEPTION 'Event not found';
    END IF;

    SELECT up.organization_id INTO v_target_user_org_id
    FROM public.users_profile up
    WHERE up.user_id = p_user_id;

    IF v_target_user_org_id IS NULL THEN
      RAISE EXCEPTION 'Target user has no organization';
    END IF;

    IF v_target_user_org_id IS DISTINCT FROM v_event_org_id THEN
      RAISE EXCEPTION 'Forbidden: User organization mismatch for event';
    END IF;

    INSERT INTO public.event_staff (
        event_id,
        user_id,
        role,
        quota_standard,
        quota_guest,
        quota_invitation
    )
    VALUES (
        p_event_id,
        p_user_id,
        p_role,
        p_quota_standard,
        p_quota_guest,
        p_quota_invitation
    )
    ON CONFLICT (event_id, user_id)
    DO UPDATE SET
        role = excluded.role,
        quota_standard = excluded.quota_standard,
        quota_guest = excluded.quota_guest,
        quota_invitation = excluded.quota_invitation;
END;
$$;

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

  RETURN COALESCE(v_result, '{}'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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
        FROM public.checkins
        WHERE event_id = p_event_id AND result = 'allowed'
        GROUP BY 1
        ORDER BY 1
      ) h
    ),
    'rrpp_performance', (
      SELECT jsonb_agg(p) FROM (
        SELECT coalesce(up.display_name, u.email) AS name, t.type, count(*) AS count
        FROM public.tickets t
        LEFT JOIN auth.users u ON t.created_by = u.id
        LEFT JOIN public.users_profile up ON u.id = up.user_id
        WHERE t.event_id = p_event_id
        GROUP BY 1, 2
        ORDER BY 3 DESC
      ) p
    ),
    'sales_timeline', (
      SELECT jsonb_agg(s) FROM (
        SELECT created_at::date AS day, count(*) AS count, sum(price) AS revenue
        FROM public.tickets
        WHERE event_id = p_event_id
        GROUP BY 1
        ORDER BY 1
      ) s
    )
  ) INTO v_stats;

  RETURN v_stats;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
