-- Fix: Checkins RLS policy was allowing cross-tenant reads.
-- Old policy: auth.role() = 'authenticated' (any logged-in user sees ALL checkins)
-- New policy: Scoped to caller's organization via events + users_profile join.

DROP POLICY IF EXISTS "Checkins Staff Read" ON public.checkins;
CREATE POLICY "Checkins Staff Read" ON public.checkins
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.events e
    JOIN public.users_profile up ON up.organization_id = e.organization_id
    WHERE e.id = checkins.event_id
      AND up.user_id = auth.uid()
  )
);
