-- P2 hardening: private tickets bucket + remove public storage access
begin;

-- Ensure tickets bucket exists and is private
insert into storage.buckets (id, name, public)
values ('tickets', 'tickets', false)
on conflict (id) do update set public = excluded.public;

update storage.buckets
set public = false
where id = 'tickets';

-- Remove legacy public read policies if present
-- (names vary across bootstrap scripts)
drop policy if exists "Public Access to Ticket PDFs" on storage.objects;
drop policy if exists "Downloads" on storage.objects;

commit;
