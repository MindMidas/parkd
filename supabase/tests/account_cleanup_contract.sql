-- Run with: supabase db reset && supabase test db
-- Account cleanup is split into a durable database queue and an idempotent
-- service-role worker. These tests cover the grants, leases, and snapshots that
-- make external Stripe/Storage/Auth reconciliation retryable.
begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions, pg_catalog;
grant usage on schema extensions to anon, authenticated, service_role;
grant execute on all functions in schema extensions to anon, authenticated, service_role;
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
grant execute on function tests.query_throws(text) to anon, authenticated, service_role;

create table tests.cleanup_claims (
  user_id uuid,
  stripe_customer_id text,
  storage_objects jsonb,
  prepared boolean,
  attempt_count integer
);
grant select, insert, delete on tests.cleanup_claims to service_role;

select ok(to_regprocedure('public.request_account_deletion()') is null,
  'direct authenticated account-deletion RPC no longer exists');
select ok(not has_function_privilege('authenticated',
  'public.prepare_account_deletion(uuid)', 'EXECUTE'),
  'authenticated cannot execute account preparation');
select ok(not has_function_privilege('authenticated',
  'public.purge_expired_demo_data(integer,timestamp with time zone)', 'EXECUTE'),
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

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data) values
  ('90000000-0000-4000-8000-000000000001', 'expired-one@example.test', now(),
    '{"username":"expired_one","full_name":"Expired One"}'::jsonb),
  ('90000000-0000-4000-8000-000000000002', 'expired-two@example.test', now(),
    '{"username":"expired_two","full_name":"Expired Two"}'::jsonb);

set local role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
update public.profiles set
  stripe_customer_id = case id
    when '90000000-0000-4000-8000-000000000001'::uuid then 'cus_cleanup_one'
    else 'cus_cleanup_two'
  end,
  demo_expires_at = case id
    when '90000000-0000-4000-8000-000000000001'::uuid
      then now() - interval '2 hours'
    else now() - interval '1 hour'
  end
where id in (
  '90000000-0000-4000-8000-000000000001',
  '90000000-0000-4000-8000-000000000002'
);
insert into storage.objects(bucket_id, name, metadata) values
  ('avatars',
    '90000000-0000-4000-8000-000000000001/avatar.jpg',
    '{"mimetype":"image/jpeg","size":100}'::jsonb),
  ('listing-photos',
    '90000000-0000-4000-8000-000000000002/listing/photo.jpg',
    '{"mimetype":"image/jpeg","size":100}'::jsonb);

-- Simulate a previous worker that prepared the second profile but failed
-- before removing Storage/Auth or marking the job complete.
select is(
  public.prepare_account_deletion(
    '90000000-0000-4000-8000-000000000002'
  )->>'stripe_customer_id',
  'cus_cleanup_two',
  'preparation snapshots the external Stripe customer ID'
);

delete from tests.cleanup_claims;
insert into tests.cleanup_claims
select * from public.purge_expired_demo_data(1, now());
select is((select count(*)::integer from tests.cleanup_claims), 1,
  'cleanup claims are bounded by the requested batch limit');
select is((select user_id from tests.cleanup_claims),
  '90000000-0000-4000-8000-000000000001'::uuid,
  'oldest unprepared expired profile is claimed first');
select is((select stripe_customer_id from tests.cleanup_claims), 'cus_cleanup_one',
  'claim preserves Stripe ID before profile preparation');
select ok((select storage_objects @> jsonb_build_array(jsonb_build_object(
    'bucket_id', 'avatars',
    'name', '90000000-0000-4000-8000-000000000001/avatar.jpg'
  )) from tests.cleanup_claims),
  'claim preserves Storage paths before profile preparation');
select ok((select deleted_at is null and stripe_customer_id = 'cus_cleanup_one'
  from public.profiles where id = '90000000-0000-4000-8000-000000000001'),
  'claiming does not prematurely anonymize the profile');

delete from tests.cleanup_claims;
insert into tests.cleanup_claims
select * from public.purge_expired_demo_data(1, now());
select is((select count(*)::integer from tests.cleanup_claims), 1,
  'a leased job does not consume another batch slot');
select is((select user_id from tests.cleanup_claims),
  '90000000-0000-4000-8000-000000000002'::uuid,
  'an already-prepared profile remains a cleanup candidate');
select ok((select prepared from tests.cleanup_claims),
  'candidate tells the worker that database preparation already happened');
select is((select stripe_customer_id from tests.cleanup_claims), 'cus_cleanup_two',
  'prepared candidate retains its pre-anonymization Stripe ID');
select ok((select storage_objects @> jsonb_build_array(jsonb_build_object(
    'bucket_id', 'listing-photos',
    'name', '90000000-0000-4000-8000-000000000002/listing/photo.jpg'
  )) from tests.cleanup_claims),
  'prepared candidate retains Storage paths until external cleanup completes');

select is(
  public.prepare_account_deletion(
    '90000000-0000-4000-8000-000000000002'
  )->>'stripe_customer_id',
  'cus_cleanup_two',
  'repeated preparation is idempotent and does not lose the Stripe snapshot'
);
select ok(public.record_account_deletion_failure(
  '90000000-0000-4000-8000-000000000002', 'auth_failed'),
  'worker can persist a safe failure code and release the lease');
delete from tests.cleanup_claims;
insert into tests.cleanup_claims
select * from public.purge_expired_demo_data(1, now());
select is((select attempt_count from tests.cleanup_claims), 2,
  'released prepared job is immediately reclaimable with a new attempt');

-- Auth removal cannot cascade the anonymized relational profile. The durable
-- job remains independently completeable if a post-Auth RPC must be retried.
reset role;
delete from auth.users where id = '90000000-0000-4000-8000-000000000002';
set local role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
select ok(exists(select 1 from public.profiles
  where id = '90000000-0000-4000-8000-000000000002'),
  'anonymized relational profile survives Auth user deletion');
select ok(public.complete_account_deletion(
  '90000000-0000-4000-8000-000000000002'),
  'prepared cleanup job can be completed after Auth deletion');

select is(
  public.prepare_account_deletion(
    '90000000-0000-4000-8000-000000000001'
  )->>'stripe_customer_id',
  'cus_cleanup_one',
  'unprepared claim can be prepared without losing its snapshot'
);
select ok(public.complete_account_deletion(
  '90000000-0000-4000-8000-000000000001'),
  'first cleanup job completes idempotently');
delete from tests.cleanup_claims;
insert into tests.cleanup_claims
select * from public.purge_expired_demo_data(10, now() + interval '6 minutes');
select is((select count(*)::integer from tests.cleanup_claims), 0,
  'completed jobs are not returned to the worker');
delete from tests.cleanup_claims;
insert into tests.cleanup_claims
select * from public.purge_expired_demo_data(10, now() + interval '8 days');
select is((select count(*)::integer from tests.cleanup_claims), 0,
  'expired demo profiles are not re-enqueued after snapshot retention ends');
select ok((select bool_and(stripe_customer_id is null
    and storage_objects = '[]'::jsonb)
  from public.account_deletion_jobs),
  'external cleanup snapshots are scrubbed after seven days');
select is((select count(*)::integer from public.account_deletion_jobs), 2,
  'non-sensitive completion tombstones prevent repeated account cleanup');
select ok(tests.query_throws(
  'select * from public.purge_expired_demo_data(0, now())'),
  'cleanup rejects an unbounded or empty batch limit');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub',
  '90000000-0000-4000-8000-000000000001', true);
select ok(tests.query_throws($q$
  select public.prepare_account_deletion(
    '90000000-0000-4000-8000-000000000001'
  )
$q$), 'matching JWT identity still cannot bypass the service-only Edge layer');
reset role;

select * from finish();
rollback;
