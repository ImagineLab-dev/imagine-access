-- P3 deploy/verify helper (execute in Supabase SQL Editor)

-- 1) Apply only P3 hardening migration logic
DO $$
DECLARE
  fn record;
BEGIN
  FOR fn IN
    SELECT
      p.oid::regprocedure AS signature
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prosecdef = true
      AND p.prokind = 'f'
      AND (
        p.proconfig IS NULL
        OR NOT EXISTS (
          SELECT 1
          FROM unnest(p.proconfig) AS cfg
          WHERE cfg LIKE 'search_path=%'
        )
      )
  LOOP
    EXECUTE format(
      'ALTER FUNCTION %s SET search_path = public, pg_temp',
      fn.signature
    );
  END LOOP;
END $$;

-- 2) Verify: all SECURITY DEFINER functions in public must include search_path
SELECT
  p.oid::regprocedure AS function_signature,
  p.proconfig
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prosecdef = true
  AND (
    p.proconfig IS NULL
    OR NOT EXISTS (
      SELECT 1
      FROM unnest(p.proconfig) AS cfg
      WHERE cfg LIKE 'search_path=%'
    )
  )
ORDER BY 1;

-- Expected result: 0 rows
