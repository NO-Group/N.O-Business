-- MFSL stores staff profiles in MongoDB through the data-api Edge Function.
-- A legacy public trigger on auth.users still attempted to mirror new users
-- into a removed/incompatible Postgres profile table, causing GoTrue's
-- "Database error creating new user" after the Auth row insert.
DO $$
DECLARE
  trigger_row record;
  remaining integer;
BEGIN
  -- Profiles are owned exclusively by MongoDB/data-api. Therefore this
  -- project needs no user-defined trigger on auth.users. Do not filter by
  -- function schema: legacy triggers may call public, auth, or extensions
  -- functions, and filtering by public previously left the broken trigger.
  FOR trigger_row IN
    SELECT t.tgname
    FROM pg_trigger t
    WHERE t.tgrelid = 'auth.users'::regclass
      AND NOT t.tgisinternal
  LOOP
    RAISE NOTICE 'Dropping user-defined auth.users trigger: %', trigger_row.tgname;
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON auth.users', trigger_row.tgname);
  END LOOP;

  SELECT count(*) INTO remaining
  FROM pg_trigger t
  WHERE t.tgrelid = 'auth.users'::regclass
    AND NOT t.tgisinternal;

  IF remaining <> 0 THEN
    RAISE EXCEPTION 'auth.users still has % user-defined trigger(s)', remaining;
  END IF;
END $$;

-- Return an auditable result to the Management API/GitHub Actions log.
SELECT json_build_object(
  'auth_users_user_triggers', count(*),
  'verified', count(*) = 0
) AS auth_trigger_repair
FROM pg_trigger t
WHERE t.tgrelid = 'auth.users'::regclass
  AND NOT t.tgisinternal;
