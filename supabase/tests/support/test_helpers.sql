-- Minimal assertion + identity helpers for the SQL test suite.
create schema tests;
grant usage on schema tests to public;

create function tests.create_user(p_email text, p_confirmed boolean default true)
returns uuid language plpgsql security definer as $$
declare v_id uuid;
begin
  insert into auth.users (email, email_confirmed_at, raw_user_meta_data)
  values (p_email, case when p_confirmed then now() end,
          jsonb_build_object('full_name', initcap(split_part(p_email, '@', 1))))
  returning id into v_id;
  return v_id;
end $$;

-- Become a signed-in API user, exactly as PostgREST would present one.
create function tests.login(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, false);
  perform set_config('role', 'authenticated', false);
end $$;

create function tests.anonymous() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '', false);
  perform set_config('role', 'anon', false);
end $$;

-- Back to the migration/superuser role (bypasses RLS) for fixtures.
create function tests.superuser() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '', false);
  perform set_config('role', 'none', false);
end $$;

create function tests.ok(p_condition boolean, p_message text) returns void
language plpgsql as $$
begin
  if p_condition is not true then
    raise exception 'FAILED: %', p_message;
  end if;
  raise notice 'ok - %', p_message;
end $$;

create function tests.count(p_sql text) returns bigint language plpgsql as $$
declare v bigint;
begin
  execute 'select count(*) from (' || p_sql || ') t' into v;
  return v;
end $$;

-- Passes when p_sql raises an error whose SQLSTATE matches p_sqlstate (LIKE).
create function tests.throws(p_sql text, p_sqlstate text, p_message text) returns void
language plpgsql as $$
declare v_state text; v_error text;
begin
  begin
    execute p_sql;
  exception when others then
    v_state := sqlstate; v_error := sqlerrm;
  end;
  if v_state is null then
    raise exception 'FAILED (no error raised): %', p_message;
  end if;
  if v_state not like p_sqlstate then
    raise exception 'FAILED: % - expected SQLSTATE %, got % (%)', p_message, p_sqlstate, v_state, v_error;
  end if;
  raise notice 'ok - % [%]', p_message, v_state;
end $$;

-- Passes when a DML statement runs but touches zero rows (RLS filtered it).
create function tests.affects_none(p_sql text, p_message text) returns void
language plpgsql as $$
declare v bigint;
begin
  execute p_sql;
  get diagnostics v = row_count;
  if v <> 0 then
    raise exception 'FAILED: % - % row(s) affected', p_message, v;
  end if;
  raise notice 'ok - %', p_message;
end $$;

grant execute on all functions in schema tests to public;
