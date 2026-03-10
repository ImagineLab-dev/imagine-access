CREATE OR REPLACE FUNCTION public.get_my_organization_id()
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
	SELECT up.organization_id
	FROM public.users_profile up
	WHERE up.user_id = auth.uid()
	LIMIT 1
$$;

REVOKE ALL ON FUNCTION public.get_my_organization_id() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_my_organization_id() TO authenticated;

DROP POLICY IF EXISTS "Users Profile Read" ON public.users_profile;
CREATE POLICY "Users Profile Read" ON public.users_profile
FOR SELECT USING (
	user_id = auth.uid()
	OR organization_id = public.get_my_organization_id()
);

DROP POLICY IF EXISTS "Users Profile Admin Insert" ON public.users_profile;
CREATE POLICY "Users Profile Admin Insert" ON public.users_profile
FOR INSERT WITH CHECK (
	COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', auth.jwt() -> 'user_metadata' ->> 'role', 'rrpp') = 'admin'
	AND organization_id = public.get_my_organization_id()
);

DROP POLICY IF EXISTS "Users Profile Admin Update" ON public.users_profile;
CREATE POLICY "Users Profile Admin Update" ON public.users_profile
FOR UPDATE USING (
	COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', auth.jwt() -> 'user_metadata' ->> 'role', 'rrpp') = 'admin'
	AND organization_id = public.get_my_organization_id()
)
WITH CHECK (
	organization_id = public.get_my_organization_id()
);

DROP POLICY IF EXISTS "Users Profile Admin Delete" ON public.users_profile;
CREATE POLICY "Users Profile Admin Delete" ON public.users_profile
FOR DELETE USING (
	COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', auth.jwt() -> 'user_metadata' ->> 'role', 'rrpp') = 'admin'
	AND organization_id = public.get_my_organization_id()
);
