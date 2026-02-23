-- Add explicit relationship between tickets and users_profile for PostgREST joins
-- This allows using .select('*, users_profile!created_by(display_name)')

-- 1. Ensure the foreign key exists
alter table public.tickets
drop constraint if exists tickets_created_by_fkey;

alter table public.tickets
add constraint tickets_created_by_fkey
foreign key (created_by)
references public.users_profile(user_id);

-- 2. Optional: Add for checkins as well if we want operator info
alter table public.checkins
drop constraint if exists checkins_operator_user_fkey;

alter table public.checkins
add constraint checkins_operator_user_fkey
foreign key (operator_user)
references public.users_profile(user_id);
