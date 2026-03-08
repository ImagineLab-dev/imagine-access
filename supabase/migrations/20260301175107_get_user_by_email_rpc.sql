-- RPC function to safely look up a user_id by email from auth.users.
-- Only callable with service_role key (Edge Functions).
-- Prevents the need to call listUsers() which returns ALL users.

CREATE OR REPLACE FUNCTION public.get_user_id_by_email(p_email TEXT)
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT id FROM auth.users WHERE email = p_email LIMIT 1;
$$;

-- Revoke public access; only service_role (used by Edge Functions) can call this
REVOKE ALL ON FUNCTION public.get_user_id_by_email(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_user_id_by_email(TEXT) FROM authenticated;
REVOKE ALL ON FUNCTION public.get_user_id_by_email(TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_user_id_by_email(TEXT) TO service_role;
