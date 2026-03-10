-- ==========================================
-- RPC BÚSQUEDA UNIFICADA (V1)
-- Maneja tanto usuarios autenticados (JWT) como dispositivos (PIN)
-- ==========================================

create or replace function public.search_tickets_unified(
  p_query text,
  p_type text, -- 'doc' or 'phone'
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
  -- 1. Determinar Identidad
  v_uid := auth.uid();
  
  -- A. Usuario Logueado (Email/Pass - Admin, RRPP, Door)
  if v_uid is not null then
    v_is_authenticated := true;
  else
    -- B. Dispositivo (PIN - Door)
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
             and d.pin_hash = encode(digest(d.pin_salt || ':' || p_device_pin, 'sha256'), 'hex')
           )
           or (d.pin_hash is null and d.pin = p_device_pin)
         )
       limit 1;

       if v_device_org_id is not null then
         v_is_authenticated := true;
       end if;
    end if;
  end if;

  -- 2. Validar Acceso
  if v_is_authenticated is not true then
    return jsonb_build_object('error', 'Unauthorized: No valid session or device credentials');
  end if;

  -- 2b. Validar tipo de búsqueda
  if p_type not in ('doc', 'phone') then
    return jsonb_build_object('error', 'Invalid search type. Use doc or phone');
  end if;

  -- 2c. Guard multitenant por evento (JWT o dispositivo)
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

  -- 3. Ejecutar búsqueda (Limpiando formatos)
  -- Nota: Usamos SECURITY DEFINER para saltar RLS, ya que ya validamos permiso arriba.
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
