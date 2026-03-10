-- =============================================================================
-- IMAGINE ACCESS - ONE SQL MASTER REVIEWED (2026-02-28)
-- Purpose: single idempotent script to unify schema, multitenancy and core RPCs
-- Safe to re-run. Includes secure function hardening (search_path + auth guards).
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 0) Extensions
-- -----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- -----------------------------------------------------------------------------
-- 0b) Base tables (self-contained bootstrap)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.users_profile (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
  display_name TEXT,
  role TEXT DEFAULT 'rrpp' CHECK (role IN ('admin', 'rrpp', 'door')),
  created_at TIMESTAMPTZ DEFAULT now()
);

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

ALTER TABLE public.events ADD COLUMN IF NOT EXISTS is_archived BOOLEAN DEFAULT false;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT 'PYG';

CREATE TABLE IF NOT EXISTS public.ticket_types (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID REFERENCES public.events(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  category TEXT DEFAULT 'standard' CHECK (category IN ('standard', 'guest', 'staff', 'invitation')),
  price NUMERIC DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  color TEXT DEFAULT '#4F46E5',
  valid_until TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (event_id, name)
);

ALTER TABLE public.ticket_types ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT 'PYG';

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
  scanned_at TIMESTAMPTZ,
  email_sent_at TIMESTAMPTZ,
  pdf_url TEXT,
  qr_token TEXT UNIQUE,
  request_id UUID UNIQUE
);

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
  request_id UUID UNIQUE
);

CREATE TABLE IF NOT EXISTS public.devices (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  device_id TEXT,
  pin TEXT,
  pin_hash TEXT,
  pin_salt TEXT,
  alias TEXT,
  enabled BOOLEAN DEFAULT true,
  last_active_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO storage.buckets (id, name, public)
VALUES ('tickets', 'tickets', false)
ON CONFLICT (id) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 1) Schema hardening (idempotent)
-- -----------------------------------------------------------------------------

-- Organizations
CREATE TABLE IF NOT EXISTS public.organizations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Multitenant links
ALTER TABLE public.users_profile
  ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES public.organizations(id) ON DELETE SET NULL;

ALTER TABLE public.events
  ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS city TEXT;

ALTER TABLE public.devices
  ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;

-- Device credential hardening
ALTER TABLE public.devices ADD COLUMN IF NOT EXISTS pin TEXT;
ALTER TABLE public.devices ADD COLUMN IF NOT EXISTS pin_hash TEXT;
ALTER TABLE public.devices ADD COLUMN IF NOT EXISTS pin_salt TEXT;

-- Ticket types/dashboard compatibility
ALTER TABLE public.ticket_types ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'standard';
ALTER TABLE public.ticket_types ADD COLUMN IF NOT EXISTS color TEXT DEFAULT '#4F46E5';
ALTER TABLE public.ticket_types ADD COLUMN IF NOT EXISTS valid_until TIMESTAMPTZ DEFAULT NULL;

-- Tickets/checkins compatibility
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'valid';
ALTER TABLE public.checkins ADD COLUMN IF NOT EXISTS method TEXT DEFAULT 'qr';
ALTER TABLE public.checkins ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE public.checkins ADD COLUMN IF NOT EXISTS request_id UUID;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'checkins_request_id_unique'
      AND conrelid = 'public.checkins'::regclass
  ) THEN
    ALTER TABLE public.checkins ADD CONSTRAINT checkins_request_id_unique UNIQUE (request_id);
  END IF;
END $$;

-- Event staff table (used by dashboard/quota/team assignment)
CREATE TABLE IF NOT EXISTS public.event_staff (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID REFERENCES public.events(id) ON DELETE CASCADE NOT NULL,
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

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'event_staff_event_id_user_id_key'
      AND conrelid = 'public.event_staff'::regclass
  ) THEN
    ALTER TABLE public.event_staff
      ADD CONSTRAINT event_staff_event_id_user_id_key UNIQUE (event_id, user_id);
  END IF;
END $$;

ALTER TABLE public.event_staff ADD COLUMN IF NOT EXISTS quota_limit INT DEFAULT 0;
ALTER TABLE public.event_staff ADD COLUMN IF NOT EXISTS quota_used INT DEFAULT 0;
ALTER TABLE public.event_staff ADD COLUMN IF NOT EXISTS quota_standard INT DEFAULT 0;
ALTER TABLE public.event_staff ADD COLUMN IF NOT EXISTS quota_standard_used INT DEFAULT 0;
ALTER TABLE public.event_staff ADD COLUMN IF NOT EXISTS quota_guest INT DEFAULT 0;
ALTER TABLE public.event_staff ADD COLUMN IF NOT EXISTS quota_guest_used INT DEFAULT 0;
ALTER TABLE public.event_staff ADD COLUMN IF NOT EXISTS quota_invitation INT DEFAULT 0;
ALTER TABLE public.event_staff ADD COLUMN IF NOT EXISTS quota_invitation_used INT DEFAULT 0;

-- Audit logs table (used by edge functions create_ticket/validate_ticket)
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id),
  action TEXT NOT NULL,
  resource TEXT,
  details JSONB,
  ip_address TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- App settings table (used by settings_repository)
CREATE TABLE IF NOT EXISTS public.app_settings (
  setting_key TEXT NOT NULL,
  organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE NOT NULL,
  setting_value TEXT,
  updated_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (setting_key, organization_id)
);

DO $$
BEGIN
  BEGIN
    ALTER TABLE public.devices ALTER COLUMN pin DROP NOT NULL;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;
END $$;

-- Requested missing columns for tickets
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'tickets' AND column_name = 'scanned_at'
  ) THEN
    ALTER TABLE public.tickets ADD COLUMN scanned_at TIMESTAMPTZ DEFAULT NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'tickets' AND column_name = 'email_sent_at'
  ) THEN
    ALTER TABLE public.tickets ADD COLUMN email_sent_at TIMESTAMPTZ DEFAULT NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'tickets' AND column_name = 'request_id'
  ) THEN
    ALTER TABLE public.tickets ADD COLUMN request_id UUID;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'tickets_request_id_unique'
      AND conrelid = 'public.tickets'::regclass
  ) THEN
    ALTER TABLE public.tickets ADD CONSTRAINT tickets_request_id_unique UNIQUE (request_id);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_users_profile_org ON public.users_profile(organization_id);
CREATE INDEX IF NOT EXISTS idx_events_org ON public.events(organization_id);
CREATE INDEX IF NOT EXISTS idx_devices_org ON public.devices(organization_id);
CREATE INDEX IF NOT EXISTS idx_tickets_request_id ON public.tickets(request_id);
CREATE INDEX IF NOT EXISTS idx_checkins_request_id ON public.checkins(request_id);
CREATE INDEX IF NOT EXISTS idx_event_staff_event_user ON public.event_staff(event_id, user_id);

-- -----------------------------------------------------------------------------
-- 2) RLS policies (organization isolation)
-- -----------------------------------------------------------------------------
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users_profile ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checkins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users see own organization" ON public.organizations;
CREATE POLICY "Users see own organization" ON public.organizations
FOR ALL USING (
  owner_id = auth.uid()
  OR id IN (
    SELECT up.organization_id
    FROM public.users_profile up
    WHERE up.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Organization Events Read" ON public.events;
CREATE POLICY "Organization Events Read" ON public.events
FOR SELECT USING (
  organization_id IN (
    SELECT up.organization_id
    FROM public.users_profile up
    WHERE up.user_id = auth.uid()
  )
  OR created_by = auth.uid()
);

DROP POLICY IF EXISTS "Organization Events Insert" ON public.events;
CREATE POLICY "Organization Events Insert" ON public.events
FOR INSERT WITH CHECK (
  COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', auth.jwt() -> 'user_metadata' ->> 'role', 'rrpp') = 'admin'
  AND
  organization_id IN (
    SELECT up.organization_id
    FROM public.users_profile up
    WHERE up.user_id = auth.uid()
  )
  OR created_by = auth.uid()
);

DROP POLICY IF EXISTS "Organization Events Update" ON public.events;
CREATE POLICY "Organization Events Update" ON public.events
FOR UPDATE USING (
  COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', auth.jwt() -> 'user_metadata' ->> 'role', 'rrpp') = 'admin'
  AND
  organization_id IN (
    SELECT up.organization_id
    FROM public.users_profile up
    WHERE up.user_id = auth.uid()
  )
  OR created_by = auth.uid()
);

DROP POLICY IF EXISTS "Organization Events Delete" ON public.events;
CREATE POLICY "Organization Events Delete" ON public.events
FOR DELETE USING (
  COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', auth.jwt() -> 'user_metadata' ->> 'role', 'rrpp') = 'admin'
  AND
  organization_id IN (
    SELECT up.organization_id
    FROM public.users_profile up
    WHERE up.user_id = auth.uid()
  )
  OR created_by = auth.uid()
);

DROP POLICY IF EXISTS "Organization Types Read" ON public.ticket_types;
CREATE POLICY "Organization Types Read" ON public.ticket_types
FOR SELECT USING (
  event_id IN (
    SELECT e.id
    FROM public.events e
    WHERE e.organization_id IN (
      SELECT up.organization_id
      FROM public.users_profile up
      WHERE up.user_id = auth.uid()
    )
    OR e.created_by = auth.uid()
  )
);

DROP POLICY IF EXISTS "Organization Types Write" ON public.ticket_types;
CREATE POLICY "Organization Types Write" ON public.ticket_types
FOR ALL USING (
  COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', auth.jwt() -> 'user_metadata' ->> 'role', 'rrpp') = 'admin'
  AND event_id IN (
    SELECT e.id
    FROM public.events e
    WHERE e.organization_id IN (
      SELECT up.organization_id
      FROM public.users_profile up
      WHERE up.user_id = auth.uid()
    )
    OR e.created_by = auth.uid()
  )
)
WITH CHECK (
  event_id IN (
    SELECT e.id
    FROM public.events e
    WHERE e.organization_id IN (
      SELECT up.organization_id
      FROM public.users_profile up
      WHERE up.user_id = auth.uid()
    )
    OR e.created_by = auth.uid()
  )
);

DROP POLICY IF EXISTS "Organization Tickets Read" ON public.tickets;
CREATE POLICY "Organization Tickets Read" ON public.tickets
FOR SELECT USING (
  event_id IN (
    SELECT e.id
    FROM public.events e
    WHERE e.organization_id IN (
      SELECT up.organization_id
      FROM public.users_profile up
      WHERE up.user_id = auth.uid()
    )
    OR e.created_by = auth.uid()
  )
  OR created_by = auth.uid()
);

DROP POLICY IF EXISTS "Organization Devices Access" ON public.devices;
CREATE POLICY "Organization Devices Access" ON public.devices
FOR ALL USING (
  organization_id IN (
    SELECT up.organization_id
    FROM public.users_profile up
    WHERE up.user_id = auth.uid()
  )
);

CREATE OR REPLACE FUNCTION public.get_my_organization_id()
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT up.organization_id
  FROM public.users_profile up
  WHERE up.user_id = auth.uid()
  LIMIT 1
$$;

REVOKE ALL ON FUNCTION public.get_my_organization_id() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_my_organization_id() TO authenticated;

DROP POLICY IF EXISTS "Users Profile Read" ON public.users_profile;
CREATE POLICY "Users Profile Read" ON public.users_profile
FOR SELECT USING (
  user_id = auth.uid()
  OR organization_id = public.get_my_organization_id()
);

DROP POLICY IF EXISTS "Users Profile Admin Insert" ON public.users_profile;
CREATE POLICY "Users Profile Admin Insert" ON public.users_profile
FOR INSERT WITH CHECK (
  COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', auth.jwt() -> 'user_metadata' ->> 'role', 'rrpp') = 'admin'
  AND organization_id = public.get_my_organization_id()
);

DROP POLICY IF EXISTS "Users Profile Admin Update" ON public.users_profile;
CREATE POLICY "Users Profile Admin Update" ON public.users_profile
FOR UPDATE USING (
  COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', auth.jwt() -> 'user_metadata' ->> 'role', 'rrpp') = 'admin'
  AND organization_id = public.get_my_organization_id()
)
WITH CHECK (
  organization_id = public.get_my_organization_id()
);

DROP POLICY IF EXISTS "Users Profile Admin Delete" ON public.users_profile;
CREATE POLICY "Users Profile Admin Delete" ON public.users_profile
FOR DELETE USING (
  COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', auth.jwt() -> 'user_metadata' ->> 'role', 'rrpp') = 'admin'
  AND organization_id = public.get_my_organization_id()
);

DROP POLICY IF EXISTS "Event Staff Read" ON public.event_staff;
CREATE POLICY "Event Staff Read" ON public.event_staff
FOR SELECT USING (
  user_id = auth.uid()
  OR (
    COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', auth.jwt() -> 'user_metadata' ->> 'role', 'rrpp') = 'admin'
    AND event_id IN (
      SELECT e.id FROM public.events e
      WHERE e.organization_id IN (
        SELECT up.organization_id FROM public.users_profile up WHERE up.user_id = auth.uid()
      )
    )
  )
);

DROP POLICY IF EXISTS "Event Staff Admin Write" ON public.event_staff;
CREATE POLICY "Event Staff Admin Write" ON public.event_staff
FOR ALL USING (
  COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', auth.jwt() -> 'user_metadata' ->> 'role', 'rrpp') = 'admin'
  AND event_id IN (
    SELECT e.id FROM public.events e
    WHERE e.organization_id IN (
      SELECT up.organization_id FROM public.users_profile up WHERE up.user_id = auth.uid()
    )
  )
)
WITH CHECK (
  event_id IN (
    SELECT e.id FROM public.events e
    WHERE e.organization_id IN (
      SELECT up.organization_id FROM public.users_profile up WHERE up.user_id = auth.uid()
    )
  )
);

DROP POLICY IF EXISTS "App Settings Read" ON public.app_settings;
CREATE POLICY "App Settings Tenant Read" ON public.app_settings
FOR SELECT USING (
  organization_id = public.get_my_organization_id()
);

DROP POLICY IF EXISTS "App Settings Write" ON public.app_settings;
CREATE POLICY "App Settings Tenant Write" ON public.app_settings
FOR ALL USING (
  COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', auth.jwt() -> 'user_metadata' ->> 'role', 'rrpp') = 'admin'
  AND organization_id = public.get_my_organization_id()
)
WITH CHECK (
  COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', auth.jwt() -> 'user_metadata' ->> 'role', 'rrpp') = 'admin'
  AND organization_id = public.get_my_organization_id()
);

DROP POLICY IF EXISTS "Audit Logs Admin Read" ON public.audit_logs;
CREATE POLICY "Audit Logs Admin Read" ON public.audit_logs
FOR SELECT USING (
  COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', auth.jwt() -> 'user_metadata' ->> 'role', 'rrpp') = 'admin'
);

DROP POLICY IF EXISTS "Audit Logs Insert" ON public.audit_logs;
CREATE POLICY "Audit Logs Insert" ON public.audit_logs
FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Checkins Staff Read" ON public.checkins;
CREATE POLICY "Checkins Staff Read" ON public.checkins
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.events e
    JOIN public.users_profile up ON up.organization_id = e.organization_id
    WHERE e.id = checkins.event_id
      AND up.user_id = auth.uid()
  )
);

-- RPC: Safely resolve user_id by email (service_role only)
CREATE OR REPLACE FUNCTION public.get_user_id_by_email(p_email TEXT)
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT id FROM auth.users WHERE email = p_email LIMIT 1;
$$;
REVOKE ALL ON FUNCTION public.get_user_id_by_email(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_user_id_by_email(TEXT) FROM authenticated;
REVOKE ALL ON FUNCTION public.get_user_id_by_email(TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_user_id_by_email(TEXT) TO service_role;

-- -----------------------------------------------------------------------------
-- 2b) Realtime publication
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

-- -----------------------------------------------------------------------------
-- 3) Organization helper RPCs
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.increment_quota_category_usage()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_category TEXT;
BEGIN
  SELECT tt.category
  INTO v_category
  FROM public.ticket_types tt
  WHERE tt.event_id = NEW.event_id
    AND tt.name = NEW.type
  LIMIT 1;

  IF v_category = 'guest' THEN
    UPDATE public.event_staff
    SET quota_guest_used = COALESCE(quota_guest_used, 0) + 1
    WHERE event_id = NEW.event_id AND user_id = NEW.created_by;
  ELSIF v_category = 'invitation' THEN
    UPDATE public.event_staff
    SET quota_invitation_used = COALESCE(quota_invitation_used, 0) + 1
    WHERE event_id = NEW.event_id AND user_id = NEW.created_by;
  ELSE
    UPDATE public.event_staff
    SET quota_standard_used = COALESCE(quota_standard_used, 0) + 1
    WHERE event_id = NEW.event_id AND user_id = NEW.created_by;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_ticket_created_quota_category ON public.tickets;
CREATE TRIGGER on_ticket_created_quota_category
AFTER INSERT ON public.tickets
FOR EACH ROW EXECUTE FUNCTION public.increment_quota_category_usage();

CREATE OR REPLACE FUNCTION public.create_user_organization(
  p_user_id UUID,
  p_display_name TEXT,
  p_email TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_org_id UUID;
  v_org_slug TEXT;
BEGIN
  v_org_slug := lower(regexp_replace(
    COALESCE(p_display_name, split_part(p_email, '@', 1)),
    '[^a-zA-Z0-9]+', '-', 'g'
  )) || '-' || substr(md5(random()::text), 1, 6);

  INSERT INTO public.organizations (name, slug, owner_id)
  VALUES (
    COALESCE(p_display_name, split_part(p_email, '@', 1)) || ' Organization',
    v_org_slug,
    p_user_id
  )
  RETURNING id INTO v_org_id;

  UPDATE public.users_profile
  SET organization_id = v_org_id,
      role = 'admin'
  WHERE user_id = p_user_id;

  RETURN v_org_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.ensure_user_organization(
  p_user_id UUID,
  p_display_name TEXT,
  p_email TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_org_id UUID;
BEGIN
  SELECT organization_id INTO v_org_id
  FROM public.users_profile
  WHERE user_id = p_user_id;

  IF v_org_id IS NOT NULL THEN
    RETURN v_org_id;
  END IF;

  RETURN public.create_user_organization(p_user_id, p_display_name, p_email);
END;
$$;

-- -----------------------------------------------------------------------------
-- 4) Core RPCs (deduplicated and hardened)
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.increment_event_quota(p_event_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_limit int;
  v_used int;
BEGIN
  SELECT quota_limit, quota_used
  INTO v_limit, v_used
  FROM public.event_staff
  WHERE event_id = p_event_id AND user_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF COALESCE(v_used, 0) >= COALESCE(v_limit, 0) THEN
    RETURN false;
  END IF;

  UPDATE public.event_staff
  SET quota_used = COALESCE(quota_used, 0) + 1
  WHERE event_id = p_event_id AND user_id = p_user_id;

  RETURN true;
END;
$$;

-- Force drop old signature before recreate
DROP FUNCTION IF EXISTS public.search_tickets_unified(text, text, uuid, text, text);

CREATE OR REPLACE FUNCTION public.search_tickets_unified(
  p_query text,
  p_type text,
  p_event_id uuid,
  p_device_id text DEFAULT NULL::text,
  p_device_pin text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid;
  v_is_authenticated boolean := false;
  v_device_org_id uuid;
  v_event_org_id uuid;
  v_user_org_id uuid;
  v_results jsonb := '[]'::jsonb;
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
        d.id::text = p_device_id
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
  END IF;

  IF v_is_authenticated IS NOT TRUE THEN
    RETURN jsonb_build_object('error', 'Unauthorized: No valid session or device credentials');
  END IF;

  IF p_type NOT IN ('doc', 'phone') THEN
    RETURN jsonb_build_object('error', 'Invalid search type. Use doc or phone');
  END IF;

  SELECT e.organization_id
  INTO v_event_org_id
  FROM public.events e
  WHERE e.id = p_event_id;

  IF NOT FOUND THEN
    RETURN '[]'::jsonb;
  END IF;

  IF v_uid IS NOT NULL THEN
    SELECT up.organization_id
    INTO v_user_org_id
    FROM public.users_profile up
    WHERE up.user_id = v_uid;

    IF v_event_org_id IS NOT NULL AND v_user_org_id IS DISTINCT FROM v_event_org_id THEN
      RETURN jsonb_build_object('error', 'Forbidden: event outside your organization');
    END IF;
  ELSIF v_device_org_id IS DISTINCT FROM v_event_org_id THEN
    RETURN jsonb_build_object('error', 'Forbidden: event outside your organization');
  END IF;

  IF p_type = 'doc' THEN
    SELECT jsonb_agg(t)
    INTO v_results
    FROM (
      SELECT tickets.*, events.name AS event_name
      FROM public.tickets
      JOIN public.events ON events.id = tickets.event_id
      WHERE tickets.event_id = p_event_id
        AND (
          tickets.buyer_doc ILIKE '%' || p_query || '%'
          OR regexp_replace(tickets.buyer_doc, '\\D', '', 'g') = regexp_replace(p_query, '\\D', '', 'g')
        )
    ) t;
  ELSE
    SELECT jsonb_agg(t)
    INTO v_results
    FROM (
      SELECT tickets.*, events.name AS event_name
      FROM public.tickets
      JOIN public.events ON events.id = tickets.event_id
      WHERE tickets.event_id = p_event_id
        AND (
          tickets.buyer_phone ILIKE '%' || p_query || '%'
          OR regexp_replace(tickets.buyer_phone, '\\D', '', 'g') = regexp_replace(p_query, '\\D', '', 'g')
        )
    ) t;
  END IF;

  RETURN COALESCE(v_results, '[]'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_device_tickets(
  p_device_id text,
  p_device_pin text,
  p_event_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_device_org_id uuid;
  v_result jsonb := '[]'::jsonb;
BEGIN
  SELECT d.organization_id
    INTO v_device_org_id
  FROM public.devices d
  WHERE d.enabled = true
    AND (
      d.id::text = p_device_id
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

  IF v_device_org_id IS NULL THEN
    RETURN '[]'::jsonb;
  END IF;

  SELECT COALESCE(jsonb_agg(x.ticket_json), '[]'::jsonb)
  INTO v_result
  FROM (
    SELECT
      to_jsonb(t)
      || jsonb_build_object(
        'events', jsonb_build_object('name', e.name),
        'users_profile', CASE
          WHEN up.user_id IS NOT NULL THEN jsonb_build_object('display_name', up.display_name)
          ELSE NULL
        END,
        'checkins', COALESCE((
          SELECT jsonb_agg(jsonb_build_object('id', c.id))
          FROM public.checkins c
          WHERE c.ticket_id = t.id
        ), '[]'::jsonb)
      ) AS ticket_json
    FROM public.tickets t
    JOIN public.events e ON t.event_id = e.id
    LEFT JOIN public.users_profile up ON t.created_by = up.user_id
    WHERE e.organization_id = v_device_org_id
      AND (p_event_id IS NULL OR t.event_id = p_event_id)
    ORDER BY t.created_at DESC
  ) x;

  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_authorized_tickets()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid;
  v_results jsonb;
BEGIN
  v_uid := auth.uid();

  SELECT jsonb_agg(
    to_jsonb(t)
    || jsonb_build_object(
      'events', jsonb_build_object('name', e.name),
      'users_profile', CASE WHEN up.user_id IS NOT NULL THEN jsonb_build_object('display_name', up.display_name) ELSE NULL END,
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
    EXISTS (
      SELECT 1 FROM public.users_profile p
      WHERE p.user_id = v_uid AND (p.role = 'admin' OR p.role = 'door')
    )
    OR t.event_id IN (
      SELECT es.event_id FROM public.event_staff es WHERE es.user_id = v_uid
    )
    OR t.created_by = v_uid;

  RETURN COALESCE(v_results, '[]'::jsonb);
END;
$$;

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
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid;
  v_caller_role text;
  v_caller_org_id uuid;
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

  SELECT up.organization_id INTO v_caller_org_id
  FROM public.users_profile up
  WHERE up.user_id = v_uid;

  IF v_caller_org_id IS NULL THEN
    RAISE EXCEPTION 'Forbidden: Caller has no organization';
  END IF;

  SELECT e.organization_id INTO v_event_org_id
  FROM public.events e
  WHERE e.id = p_event_id;

  IF v_event_org_id IS NULL THEN
    RAISE EXCEPTION 'Event not found';
  END IF;

  IF v_event_org_id IS DISTINCT FROM v_caller_org_id THEN
    RAISE EXCEPTION 'Forbidden: Event outside caller organization';
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
    quota_invitation,
    quota_limit,
    quota_used
  )
  VALUES (
    p_event_id,
    p_user_id,
    p_role,
    COALESCE(p_quota_standard, 0),
    COALESCE(p_quota_guest, 0),
    COALESCE(p_quota_invitation, 0),
    COALESCE(p_quota_standard, 0) + COALESCE(p_quota_guest, 0) + COALESCE(p_quota_invitation, 0),
    0
  )
  ON CONFLICT (event_id, user_id)
  DO UPDATE SET
    role = excluded.role,
    quota_standard = excluded.quota_standard,
    quota_guest = excluded.quota_guest,
    quota_invitation = excluded.quota_invitation,
    quota_limit = excluded.quota_limit;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_staff_dashboard(p_event_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_role text;
  v_uid uuid;
  v_result jsonb;
BEGIN
  v_uid := auth.uid();
  v_role := COALESCE(
    auth.jwt() -> 'app_metadata' ->> 'role',
    auth.jwt() -> 'user_metadata' ->> 'role',
    'rrpp'
  );

  IF v_role = 'admin' OR v_role = 'door' THEN
    v_result := jsonb_build_object(
      'total_sold', (SELECT COUNT(*) FROM public.tickets WHERE event_id = p_event_id),
      'scanned', (SELECT COUNT(DISTINCT ticket_id) FROM public.checkins WHERE event_id = p_event_id AND result = 'allowed'),
      'scanned_manual', (SELECT COUNT(DISTINCT ticket_id) FROM public.checkins WHERE event_id = p_event_id AND result = 'allowed' AND method <> 'qr'),
      'valid', (
        SELECT COUNT(*) FROM public.tickets
        WHERE event_id = p_event_id
          AND (status IS NULL OR LOWER(status) = 'valid')
          AND id NOT IN (
            SELECT c.ticket_id FROM public.checkins c
            WHERE c.event_id = p_event_id AND c.result = 'allowed'
          )
      ),
      'revenue', (SELECT COALESCE(SUM(price), 0) FROM public.tickets WHERE event_id = p_event_id),
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
        'paid_tickets_count', (SELECT COUNT(*) FROM public.tickets t JOIN public.ticket_types tt ON t.type = tt.name AND t.event_id = tt.event_id WHERE t.event_id = p_event_id AND t.created_by = v_uid AND t.price > 0),
        'paid_tickets_today', (SELECT COUNT(*) FROM public.tickets t JOIN public.ticket_types tt ON t.type = tt.name AND t.event_id = tt.event_id WHERE t.event_id = p_event_id AND t.created_by = v_uid AND t.price > 0 AND t.created_at >= CURRENT_DATE),
        'total_issued', (SELECT COUNT(*) FROM public.tickets WHERE event_id = p_event_id AND created_by = v_uid),
        'invitations_count', (SELECT COUNT(*) FROM public.tickets t JOIN public.ticket_types tt ON t.type = tt.name AND t.event_id = tt.event_id WHERE t.event_id = p_event_id AND t.created_by = v_uid AND t.price = 0),
        'quota_standard', es.quota_standard,
        'quota_standard_used', es.quota_standard_used,
        'remaining_standard', (es.quota_standard - es.quota_standard_used),
        'quota_guest', es.quota_guest,
        'quota_guest_used', es.quota_guest_used,
        'remaining_guest', (es.quota_guest - es.quota_guest_used),
        'total_scanned', (SELECT COUNT(DISTINCT t.id) FROM public.tickets t JOIN public.checkins c ON t.id = c.ticket_id WHERE t.event_id = p_event_id AND t.created_by = v_uid AND c.result = 'allowed'),
        'my_revenue', (SELECT COALESCE(SUM(price), 0) FROM public.tickets WHERE event_id = p_event_id AND created_by = v_uid)
      )
      FROM public.event_staff es
      WHERE es.event_id = p_event_id AND es.user_id = v_uid
    );
  END IF;

  RETURN COALESCE(v_result, '{"my_sales":0, "my_revenue":0}'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_event_statistics(p_event_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_role text;
  v_stats jsonb;
BEGIN
  v_role := COALESCE(
    auth.jwt() -> 'app_metadata' ->> 'role',
    auth.jwt() -> 'user_metadata' ->> 'role',
    'rrpp'
  );

  IF v_role <> 'admin' THEN
    RAISE EXCEPTION 'Unauthorized: Statistics only available for Admin role';
  END IF;

  SELECT jsonb_build_object(
    'attendance_by_hour', (
      SELECT jsonb_agg(h)
      FROM (
        SELECT to_char(date_trunc('hour', scanned_at), 'HH24:00') AS hour, count(*) AS count
        FROM public.checkins
        WHERE event_id = p_event_id AND result = 'allowed'
        GROUP BY 1
        ORDER BY 1
      ) h
    ),
    'rrpp_performance', (
      SELECT jsonb_agg(p)
      FROM (
        SELECT COALESCE(up.display_name, u.email) AS name, t.type, count(*) AS count
        FROM public.tickets t
        LEFT JOIN auth.users u ON t.created_by = u.id
        LEFT JOIN public.users_profile up ON u.id = up.user_id
        WHERE t.event_id = p_event_id
        GROUP BY 1, 2
        ORDER BY 3 DESC
      ) p
    ),
    'sales_timeline', (
      SELECT jsonb_agg(s)
      FROM (
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
$$;

-- -----------------------------------------------------------------------------
-- 5) Useful diagnostic query
-- -----------------------------------------------------------------------------
-- Run manually after execution if needed:
-- SELECT column_name, data_type, is_nullable
-- FROM information_schema.columns
-- WHERE table_schema = 'public' AND table_name = 'devices'
-- ORDER BY ordinal_position;

COMMIT;
