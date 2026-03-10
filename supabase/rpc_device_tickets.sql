CREATE OR REPLACE FUNCTION public.get_device_tickets(
    p_device_id text,
    p_device_pin text,
    p_event_id uuid default null
)
RETURNS jsonb AS $$
DECLARE
  v_is_authenticated boolean := false;
  v_result jsonb := '[]'::jsonb;
  v_device_org_id uuid;
BEGIN
  -- 1. Authenticate device (supports hashed and legacy PIN)
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

  -- 2. Return Empty if Auth Fails
  IF v_is_authenticated IS NOT TRUE THEN
    -- Debugging tip: You can raise notice here if needed
    RETURN '[]'::jsonb;
  END IF;

  -- 3. Fetch Tickets (restricted to device org, optionally event)
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
