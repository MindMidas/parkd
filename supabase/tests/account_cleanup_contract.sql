-- Run with: supabase db reset && supabase test db
-- Account deletion uses a durable database queue so external Stripe, Storage,
-- and Auth cleanup can be retried safely.
begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions, pg_catalog;
grant usage on schema extensions to anon, authenticated, service_role;
grant execute on all functions in schema extensions
  to anon, authenticated, service_role;
select no_plan();

create schema if not exists tests;
grant usage on schema tests to anon, authenticated, service_role;
create or replace function tests.query_throws(p_sql text)
returns boolean
language plpgsql
as $$
begin
  execute p_sql;
  return false;
exception when others then
  return true;
end;
$$;
grant execute on function tests.query_throws(text)
  to anon, authenticated, service_role;

create table tests.cleanup_claims (
  user_id uuid,
  stripe_customer_id text,
  storage_objects jsonb,
  prepared boolean,
  attempt_count integer
);
grant select, insert, delete on tests.cleanup_claims to service_role;

select ok(to_regprocedure('public.request_account_deletion()') is null,
  'direct authenticated account-deletion RPC does not exist');
select ok(not has_function_privilege('authenticated',
  'public.prepare_account_deletion(uuid)', 'EXECUTE'),
  'authenticated cannot execute account preparation');
select ok(not has_function_privilege('authenticated',
  'public.claim_account_deletion_jobs(integer,timestamp with time zone)', 'EXECUTE'),
  'authenticated cannot claim cleanup jobs');
select ok(not has_function_privilege('authenticated',
  'public.complete_account_deletion(uuid)', 'EXECUTE'),
  'authenticated cannot complete cleanup jobs');
select ok(not has_function_privilege('authenticated',
  'public.record_account_deletion_failure(uuid,text)', 'EXECUTE'),
  'authenticated cannot release cleanup leases');
select ok(has_function_privilege('service_role',
  'public.prepare_account_deletion(uuid)', 'EXECUTE'),
  'service role can execute account preparation');

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data) values (
  '90000000-0000-4000-8000-000000000001',
  'cleanup-user@example.test',
  now(),
  '{"username":"cleanup_user","full_name":"Cleanup User"}'::jsonb
);

set local role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
update public.profiles
set stripe_customer_id = 'cus_cleanup_one'
where id = '90000000-0000-4000-8000-000000000001';
insert into storage.objects(bucket_id, name, metadata) values (
  'avatars',
  '90000000-0000-4000-8000-000000000001/avatar.jpg',
  '{"mimetype":"image/jpeg","size":100}'::jsonb
);

select is(
  public.prepare_account_deletion(
    '90000000-0000-4000-8000-000000000001'
  )->>'stripe_customer_id',
  'cus_cleanup_one',
  'preparation snapshots the external Stripe customer ID'
);
select ok((select deleted_at is not null and stripe_customer_id is null
  from public.profiles
  where id = '90000000-0000-4000-8000-000000000001'),
  'preparation anonymizes the relational profile');

insert into tests.cleanup_claims
select * from public.claim_account_deletion_jobs(1, now());
select is((select count(*)::integer from tests.cleanup_claims), 1,
  'cleanup claims are bounded by the requested batch limit');
select is((select stripe_customer_id from tests.cleanup_claims),
  'cus_cleanup_one',
  'claim retains the pre-anonymization Stripe ID');
select ok((select prepared from tests.cleanup_claims),
  'claim reports that database preparation completed');
select ok((select storage_objects @> jsonb_build_array(jsonb_build_object(
    'bucket_id', 'avatars',
    'name', '90000000-0000-4000-8000-000000000001/avatar.jpg'
  )) from tests.cleanup_claims),
  'claim retains Storage paths until external cleanup completes');

select ok(public.record_account_deletion_failure(
  '90000000-0000-4000-8000-000000000001', 'auth_failed'),
  'worker can record a safe failure code and release the lease');
delete from tests.cleanup_claims;
insert into tests.cleanup_claims
select * from public.claim_account_deletion_jobs(1, now());
select is((select attempt_count from tests.cleanup_claims), 2,
  'released cleanup is immediately reclaimable with a new attempt');

reset role;
delete from auth.users
where id = '90000000-0000-4000-8000-000000000001';
set local role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
select ok(exists(select 1 from public.profiles
  where id = '90000000-0000-4000-8000-000000000001'),
  'anonymized relational profile survives Auth user deletion');
select ok(public.complete_account_deletion(
  '90000000-0000-4000-8000-000000000001'),
  'prepared cleanup job can be completed after Auth deletion');

delete from tests.cleanup_claims;
insert into tests.cleanup_claims
select * from public.claim_account_deletion_jobs(10, now() + interval '8 days');
select is((select count(*)::integer from tests.cleanup_claims), 0,
  'completed jobs are not returned to the worker');
select ok((select stripe_customer_id is null
    and storage_objects = '[]'::jsonb
  from public.account_deletion_jobs
  where user_id = '90000000-0000-4000-8000-000000000001'),
  'external cleanup snapshots are scrubbed after seven days');
select ok(tests.query_throws(
  'select * from public.claim_account_deletion_jobs(0, now())'),
  'cleanup rejects an empty batch limit');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub',
  '90000000-0000-4000-8000-000000000001', true);
select ok(tests.query_throws($q$
  select public.prepare_account_deletion(
    '90000000-0000-4000-8000-000000000001'
  )
$q$), 'matching JWT identity cannot bypass the service-only Edge layer');
reset role;

select * from finish();
rollback;
