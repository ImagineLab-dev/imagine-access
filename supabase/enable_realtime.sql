-- Enable Realtime for Dashboard relevant tables
-- This version is more robust and handles cases where specific publications don't exist.

-- 1. Create publication if it doesn't exist (or just use it if it does)
do $$
begin
    if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
        create publication supabase_realtime;
    end if;
end $$;

-- 2. Add tables to the publication
-- We use a DO block to ignore errors if they are already added
do $$
begin
    begin
        alter publication supabase_realtime add table public.checkins;
    exception when others then
        raise notice 'Table checkins might already be in publication';
    end;

    begin
        alter publication supabase_realtime add table public.tickets;
    exception when others then
        raise notice 'Table tickets might already be in publication';
    end;
end $$;

-- 3. Enable REPLICA IDENTITY FULL for detailed payload
alter table public.checkins replica identity full;
alter table public.tickets replica identity full;
