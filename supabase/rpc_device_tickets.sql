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
    -- Debugging tip: You can raise notice here if needed
    RETURN '[]'::jsonb;
  END IF;

  -- 3. Fetch Tickets (All tickets, similar to Admin view)
  -- Matches Flutter structure: *, events(name), users_profile(display_name), checkins(id)
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
