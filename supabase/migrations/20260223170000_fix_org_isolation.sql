-- ==============================================================================
-- FIX: Asignar organización a datos existentes y fortalecer aislamiento
-- ==============================================================================

BEGIN;

-- 1. Asignar organization_id a users_profile existentes basado en created_by de sus eventos
-- Primero, crear una organización para usuarios que tienen eventos pero no organización
INSERT INTO public.organizations (name, slug, owner_id)
SELECT 
    DISTINCT ON (e.created_by)
    COALESCE(u.raw_user_meta_data->>'display_name', u.email) || ' Organization',
    lower(regexp_replace(COALESCE(u.raw_user_meta_data->>'display_name', split_part(u.email, '@', 1)), '[^a-zA-Z0-9]+', '-', 'g')) || '-' || substr(md5(random()::text), 1, 6),
    e.created_by
FROM public.events e
JOIN auth.users u ON e.created_by = u.id
WHERE NOT EXISTS (
    SELECT 1 FROM public.organizations o WHERE o.owner_id = e.created_by
);

-- 2. Asignar organization_id a users_profile
UPDATE public.users_profile up
SET organization_id = o.id,
    role = 'admin'
FROM public.organizations o
WHERE up.user_id = o.owner_id
AND up.organization_id IS NULL;

-- 3. Asignar organization_id a eventos existentes basado en created_by
UPDATE public.events e
SET organization_id = up.organization_id
FROM public.users_profile up
WHERE e.created_by = up.user_id
AND e.organization_id IS NULL;

-- 4. Para eventos sin created_by o usuarios sin perfil, crear organización fallback
INSERT INTO public.organizations (name, slug, owner_id)
SELECT 
    'Legacy Organization ' || substr(e.id::text, 1, 8),
    'legacy-' || substr(e.id::text, 1, 8),
    e.created_by
FROM public.events e
WHERE e.organization_id IS NULL
AND e.created_by IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM public.organizations o WHERE o.owner_id = e.created_by
);

-- 5. Asignar organization_id a eventos restantes
UPDATE public.events e
SET organization_id = o.id
FROM public.organizations o
WHERE e.created_by = o.owner_id
AND e.organization_id IS NULL;

-- 7. ACTUALIZAR POLÍTICAS RLS - Quitar compatibilidad con NULL

-- Events: Solo por organización, sin fallback a NULL
DROP POLICY IF EXISTS "Organization Events Read" ON public.events;
CREATE POLICY "Organization Events Read" ON public.events
    FOR SELECT USING (
        organization_id IN (
            SELECT organization_id FROM public.users_profile WHERE user_id = auth.uid()
        ) OR
        created_by = auth.uid()
    );

DROP POLICY IF EXISTS "Organization Events Insert" ON public.events;
CREATE POLICY "Organization Events Insert" ON public.events
    FOR INSERT WITH CHECK (
        organization_id IN (
            SELECT organization_id FROM public.users_profile WHERE user_id = auth.uid()
        ) OR
        created_by = auth.uid()
    );

DROP POLICY IF EXISTS "Organization Events Update" ON public.events;
CREATE POLICY "Organization Events Update" ON public.events
    FOR UPDATE USING (
        organization_id IN (
            SELECT organization_id FROM public.users_profile WHERE user_id = auth.uid()
        ) OR
        created_by = auth.uid()
    );

DROP POLICY IF EXISTS "Organization Events Delete" ON public.events;
CREATE POLICY "Organization Events Delete" ON public.events
    FOR DELETE USING (
        organization_id IN (
            SELECT organization_id FROM public.users_profile WHERE user_id = auth.uid()
        ) OR
        created_by = auth.uid()
    );

-- Ticket Types: Solo por organización
DROP POLICY IF EXISTS "Organization Types Read" ON public.ticket_types;
CREATE POLICY "Organization Types Read" ON public.ticket_types
    FOR SELECT USING (
        event_id IN (
            SELECT id FROM public.events WHERE 
                organization_id IN (
                    SELECT organization_id FROM public.users_profile WHERE user_id = auth.uid()
                ) OR
                created_by = auth.uid()
        )
    );

-- Tickets: Solo por organización
DROP POLICY IF EXISTS "Organization Tickets Read" ON public.tickets;
CREATE POLICY "Organization Tickets Read" ON public.tickets
    FOR SELECT USING (
        event_id IN (
            SELECT id FROM public.events WHERE 
                organization_id IN (
                    SELECT organization_id FROM public.users_profile WHERE user_id = auth.uid()
                ) OR
                created_by = auth.uid()
        ) OR
        created_by = auth.uid()
    );

-- Devices: Solo por organización
DROP POLICY IF EXISTS "Organization Devices Access" ON public.devices;
CREATE POLICY "Organization Devices Access" ON public.devices
    FOR ALL USING (
        organization_id IN (
            SELECT organization_id FROM public.users_profile WHERE user_id = auth.uid()
        )
    );

COMMIT;
