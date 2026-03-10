-- P1 hardening: hashed device PIN + scoped device tickets/search

CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE public.devices
  ADD COLUMN IF NOT EXISTS pin_hash text,
  ADD COLUMN IF NOT EXISTS pin_salt text;

WITH targets AS (
  SELECT
    ctid,
    pin,
    COALESCE(pin_salt, encode(extensions.gen_random_bytes(16), 'hex')) AS new_salt
  FROM public.devices
  WHERE pin IS NOT NULL
    AND (pin_hash IS NULL OR pin_salt IS NULL)
)
UPDATE public.devices d
SET
  pin_salt = t.new_salt,
  pin_hash = encode(extensions.digest(t.new_salt || ':' || t.pin, 'sha256'), 'hex')
FROM targets t
WHERE d.ctid = t.ctid;

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
        AND d.pin_hash = encode(extensions.digest(d.pin_salt || ':' || p_device_pin, 'sha256'), 'hex')
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

CREATE OR REPLACE FUNCTION public.search_tickets_unified(
  p_query text,
  p_type text,
  p_event_id uuid,
  p_device_id text default null,
  p_device_pin text default null
)
returns jsonb
as $$
declare
  v_uid uuid;
  v_is_authenticated boolean := false;
  v_device_org_id uuid;
  v_results jsonb := '[]'::jsonb;
  v_event_org_id uuid;
  v_user_org_id uuid;
begin
  v_uid := auth.uid();

  if v_uid is not null then
    v_is_authenticated := true;
  else
    if p_device_id is not null and p_device_pin is not null then
       select d.organization_id
       into v_device_org_id
       from public.devices d
       where d.enabled = true
         and (
           cast(d.id as text) = p_device_id
           or (
             exists (
               select 1
               from information_schema.columns
               where table_schema = 'public'
                 and table_name = 'devices'
                 and column_name = 'device_id'
             )
             and d.device_id = p_device_id
           )
         )
         and (
           (
             d.pin_hash is not null
             and d.pin_salt is not null
             and d.pin_hash = encode(extensions.digest(d.pin_salt || ':' || p_device_pin, 'sha256'), 'hex')
           )
           or (d.pin_hash is null and d.pin = p_device_pin)
         )
       limit 1;

       if v_device_org_id is not null then
         v_is_authenticated := true;
       end if;
    end if;
  end if;

  if v_is_authenticated is not true then
    return jsonb_build_object('error', 'Unauthorized: No valid session or device credentials');
  end if;

  if p_type not in ('doc', 'phone') then
    return jsonb_build_object('error', 'Invalid search type. Use doc or phone');
  end if;

  select e.organization_id into v_event_org_id
  from public.events e
  where e.id = p_event_id;

  if not found then
    return '[]'::jsonb;
  end if;

  if v_uid is not null then
    select up.organization_id into v_user_org_id
    from public.users_profile up
    where up.user_id = v_uid;

    if v_event_org_id is not null and v_user_org_id is distinct from v_event_org_id then
      return jsonb_build_object('error', 'Forbidden: event outside your organization');
    end if;
  elsif v_device_org_id is distinct from v_event_org_id then
    return jsonb_build_object('error', 'Forbidden: event outside your organization');
  end if;

  if p_type = 'doc' then
    select jsonb_agg(t) into v_results
    from (
      select tickets.*, events.name as event_name
      from public.tickets
      join public.events on events.id = tickets.event_id
      where tickets.event_id = p_event_id
      and (
        tickets.buyer_doc ilike '%' || p_query || '%'
        OR
        regexp_replace(tickets.buyer_doc, '\D', '', 'g') = regexp_replace(p_query, '\D', '', 'g')
      )
    ) t;
  else
    select jsonb_agg(t) into v_results
    from (
      select tickets.*, events.name as event_name
      from public.tickets
      join public.events on events.id = tickets.event_id
      where tickets.event_id = p_event_id
      and (
        tickets.buyer_phone ilike '%' || p_query || '%'
        OR
        regexp_replace(tickets.buyer_phone, '\D', '', 'g') = regexp_replace(p_query, '\D', '', 'g')
      )
    ) t;
  end if;

  return coalesce(v_results, '[]'::jsonb);
end;
$$ language plpgsql security definer
set search_path = public, pg_temp;
