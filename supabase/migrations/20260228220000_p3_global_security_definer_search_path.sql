-- P3 hardening: enforce safe search_path on all SECURITY DEFINER functions in public schema
begin;

do $$
declare
  fn record;
begin
  for fn in
    select
      p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef = true
      and p.prokind = 'f'
      and (
        p.proconfig is null
        or not exists (
          select 1
          from unnest(p.proconfig) as cfg
          where cfg like 'search_path=%'
        )
      )
  loop
    execute format(
      'alter function %s set search_path = public, pg_temp',
      fn.signature
    );
  end loop;
end $$;

commit;
