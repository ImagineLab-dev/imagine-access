-- ==============================================================================
-- MULTITENANT ISOLATION MIGRATION
-- Purpose: Create organizations and isolate users by organization
-- ==============================================================================

BEGIN;

-- 1. CREATE ORGANIZATIONS TABLE FIRST
CREATE TABLE IF NOT EXISTS public.organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slug TEXT UNIQUE NOT NULL,
    owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS on organizations
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;

-- 2. POLICY: Users can only see their own organization (by owner)
CREATE POLICY "Users see own organization" ON public.organizations
    FOR ALL USING (owner_id = auth.uid());

-- 3. ADD organization_id TO USERS_PROFILE (now organizations exists)
ALTER TABLE public.users_profile 
    ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES public.organizations(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_users_profile_org ON public.users_profile(organization_id);

-- 4. ADD organization_id TO EVENTS
ALTER TABLE public.events 
    ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_events_org ON public.events(organization_id);

-- 5. ADD organization_id TO DEVICES
ALTER TABLE public.devices 
    ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_devices_org ON public.devices(organization_id);

-- 6. UPDATE RLS POLICIES FOR EVENTS - Isolate by organization
DROP POLICY IF EXISTS "Public Events Read" ON public.events;
DROP POLICY IF EXISTS "Organization Events Read" ON public.events;
DROP POLICY IF EXISTS "Organization Events Insert" ON public.events;
DROP POLICY IF EXISTS "Organization Events Update" ON public.events;
DROP POLICY IF EXISTS "Organization Events Delete" ON public.events;

-- Users can only see events from their organization (or own events)
CREATE POLICY "Organization Events Read" ON public.events
    FOR SELECT USING (
        organization_id IS NULL OR -- Legacy events (migration period)
        organization_id IN (
            SELECT organization_id FROM public.users_profile WHERE user_id = auth.uid()
        ) OR
        created_by = auth.uid() -- Own events
    );

-- Users can only insert events to their organization
CREATE POLICY "Organization Events Insert" ON public.events
    FOR INSERT WITH CHECK (
        organization_id IN (
            SELECT organization_id FROM public.users_profile WHERE user_id = auth.uid()
        ) OR
        created_by = auth.uid()
    );

-- Users can only update events from their organization
CREATE POLICY "Organization Events Update" ON public.events
    FOR UPDATE USING (
        organization_id IN (
            SELECT organization_id FROM public.users_profile WHERE user_id = auth.uid()
        ) OR
        created_by = auth.uid()
    );

-- Users can only delete events from their organization
CREATE POLICY "Organization Events Delete" ON public.events
    FOR DELETE USING (
        organization_id IN (
            SELECT organization_id FROM public.users_profile WHERE user_id = auth.uid()
        ) OR
        created_by = auth.uid()
    );

-- 7. UPDATE RLS FOR TICKET_TYPES (cascade via event)
DROP POLICY IF EXISTS "Public Types Read" ON public.ticket_types;
DROP POLICY IF EXISTS "Organization Types Read" ON public.ticket_types;

CREATE POLICY "Organization Types Read" ON public.ticket_types
    FOR SELECT USING (
        event_id IN (
            SELECT id FROM public.events WHERE 
                organization_id IS NULL OR
                organization_id IN (
                    SELECT organization_id FROM public.users_profile WHERE user_id = auth.uid()
                ) OR
                created_by = auth.uid()
        )
    );

-- 8. UPDATE RLS FOR TICKETS (cascade via event)
DROP POLICY IF EXISTS "Organization Tickets Read" ON public.tickets;

CREATE POLICY "Organization Tickets Read" ON public.tickets
    FOR SELECT USING (
        event_id IN (
            SELECT id FROM public.events WHERE 
                organization_id IS NULL OR
                organization_id IN (
                    SELECT organization_id FROM public.users_profile WHERE user_id = auth.uid()
                ) OR
                created_by = auth.uid()
        ) OR
        created_by = auth.uid()
    );

-- 9. UPDATE RLS FOR DEVICES
DROP POLICY IF EXISTS "Device self-access" ON public.devices;
DROP POLICY IF EXISTS "Organization Devices Access" ON public.devices;

CREATE POLICY "Organization Devices Access" ON public.devices
    FOR ALL USING (
        organization_id IS NULL OR -- Legacy devices
        organization_id IN (
            SELECT organization_id FROM public.users_profile WHERE user_id = auth.uid()
        )
    );

-- 10. FUNCTION: Create organization for new user
CREATE OR REPLACE FUNCTION public.create_user_organization(
    p_user_id UUID,
    p_display_name TEXT,
    p_email TEXT
)
RETURNS UUID AS $$
DECLARE
    v_org_id UUID;
    v_org_slug TEXT;
BEGIN
    -- Generate unique slug from email or display name
    v_org_slug := lower(regexp_replace(
        COALESCE(p_display_name, split_part(p_email, '@', 1)),
        '[^a-zA-Z0-9]+', '-', 'g'
    )) || '-' || substr(md5(random()::text), 1, 6);

    -- Create organization
    INSERT INTO public.organizations (name, slug, owner_id)
    VALUES (
        COALESCE(p_display_name, split_part(p_email, '@', 1)) || ' Organization',
        v_org_slug,
        p_user_id
    )
    RETURNING id INTO v_org_id;

    -- Update user profile with organization
    UPDATE public.users_profile
    SET organization_id = v_org_id,
        role = 'admin'  -- Owner is admin of their organization
    WHERE user_id = p_user_id;

    RETURN v_org_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 11. FUNCTION: Ensure user has organization (called from ensure_profile edge function)
CREATE OR REPLACE FUNCTION public.ensure_user_organization(
    p_user_id UUID,
    p_display_name TEXT,
    p_email TEXT
)
RETURNS UUID AS $$
DECLARE
    v_org_id UUID;
    v_exists BOOLEAN;
BEGIN
    -- Check if user already has organization
    SELECT organization_id INTO v_org_id
    FROM public.users_profile
    WHERE user_id = p_user_id;

    IF v_org_id IS NOT NULL THEN
        RETURN v_org_id;
    END IF;

    -- Create new organization
    RETURN public.create_user_organization(p_user_id, p_display_name, p_email);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 12. UPDATE RPC FUNCTIONS TO FILTER BY ORGANIZATION

-- Get events for user (filtered by organization)
CREATE OR REPLACE FUNCTION public.get_user_events()
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_org_id UUID;
BEGIN
    v_user_id := auth.uid();
    
    -- Get user's organization
    SELECT organization_id INTO v_org_id
    FROM public.users_profile
    WHERE user_id = v_user_id;

    RETURN COALESCE(
        (SELECT jsonb_agg(
            jsonb_build_object(
                'id', e.id,
                'name', e.name,
                'date', e.date,
                'venue', e.venue,
                'is_active', e.is_active,
                'slug', e.slug,
                'stats', jsonb_build_object(
                    'total', (SELECT COUNT(*) FROM public.tickets WHERE event_id = e.id),
                    'used', (SELECT COUNT(*) FROM public.tickets WHERE event_id = e.id AND status = 'used'),
                    'pending', (SELECT COUNT(*) FROM public.tickets WHERE event_id = e.id AND status = 'valid')
                )
            )
        )
        FROM public.events e
        WHERE e.organization_id = v_org_id OR e.created_by = v_user_id
        ORDER BY e.date DESC),
        '[]'::jsonb
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get dashboard stats (filtered by organization)
CREATE OR REPLACE FUNCTION public.get_org_dashboard_stats(p_org_id UUID DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_org_id UUID;
BEGIN
    v_user_id := auth.uid();
    
    -- Get organization (from param or user's org)
    IF p_org_id IS NULL THEN
        SELECT organization_id INTO v_org_id
        FROM public.users_profile
        WHERE user_id = v_user_id;
    ELSE
        v_org_id := p_org_id;
    END IF;

    RETURN jsonb_build_object(
        'total_events', (SELECT COUNT(*) FROM public.events WHERE organization_id = v_org_id OR created_by = v_user_id),
        'active_events', (SELECT COUNT(*) FROM public.events WHERE (organization_id = v_org_id OR created_by = v_user_id) AND is_active = true),
        'total_tickets', (SELECT COUNT(*) FROM public.tickets t 
                          JOIN public.events e ON t.event_id = e.id 
                          WHERE e.organization_id = v_org_id OR e.created_by = v_user_id),
        'tickets_used', (SELECT COUNT(*) FROM public.tickets t 
                         JOIN public.events e ON t.event_id = e.id 
                         WHERE (e.organization_id = v_org_id OR e.created_by = v_user_id) AND t.status = 'used'),
        'total_devices', (SELECT COUNT(*) FROM public.devices WHERE organization_id = v_org_id),
        'organization_id', v_org_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
