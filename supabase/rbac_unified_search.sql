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
  v_is_authenticated boolean;
  v_device_exists boolean;
  v_results jsonb;
begin
  -- 1. Determinar Identidad
  v_uid := auth.uid();
  
  -- A. Usuario Logueado (Email/Pass - Admin, RRPP, Door)
  if v_uid is not null then
    v_is_authenticated := true;
  else
    -- B. Dispositivo (PIN - Door)
    if p_device_id is not null and p_device_pin is not null then
       select exists (
         select 1 from public.devices 
         where id = p_device_id and pin = p_device_pin and enabled = true
       ) into v_device_exists;
       
       if v_device_exists then
         v_is_authenticated := true;
       end if;
    end if;
  end if;

  -- 2. Validar Acceso
  if v_is_authenticated is not true then
    return jsonb_build_object('error', 'Unauthorized: No valid session or device credentials');
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
$$ language plpgsql security definer;
