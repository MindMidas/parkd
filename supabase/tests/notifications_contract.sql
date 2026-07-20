-- Run with: supabase db reset && supabase test db
begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions, pg_catalog;
grant usage on schema extensions to anon, authenticated, service_role;
grant execute on all functions in schema extensions
  to anon, authenticated, service_role;
select no_plan();

create schema if not exists notification_tests;
grant usage on schema notification_tests
  to anon, authenticated, service_role;

create or replace function notification_tests.query_throws(p_sql text)
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
grant execute on function notification_tests.query_throws(text)
  to anon, authenticated, service_role;

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data) values
  ('71000000-0000-4000-8000-000000000001', 'notify-host@example.test', now(),
    '{"username":"notify_host"}'::jsonb),
  ('71000000-0000-4000-8000-000000000002', 'notify-driver@example.test', now(),
    '{"username":"notify_driver"}'::jsonb),
  ('71000000-0000-4000-8000-000000000003', 'notify-attacker@example.test', now(),
    '{"username":"notify_attacker"}'::jsonb);

set local role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
select set_config('parkd.trusted_write', 'on', true);

insert into public.listings (
  id, host_id, address, city, latitude, longitude
) values (
  '72000000-0000-4000-8000-000000000001',
  '71000000-0000-4000-8000-000000000001',
  '1 Notification Test Lane', 'Guelph', 43.5, -80.2
);

insert into public.reservations (
  id, listing_id, driver_id, host_id, start_time, end_time,
  total_price, service_fee, status, checkout_expires_at
) values (
  '73000000-0000-4000-8000-000000000001',
  '72000000-0000-4000-8000-000000000001',
  '71000000-0000-4000-8000-000000000002',
  '71000000-0000-4000-8000-000000000001',
  now() + interval '2 days', now() + interval '2 days 1 hour',
  10, 0.35, 'pending', now() + interval '15 minutes'
);

update public.reservations
set status = 'confirmed', checkout_expires_at = null
where id = '73000000-0000-4000-8000-000000000001';

insert into public.conversations (
  id, reservation_id, host_id, driver_id
) values (
  '74000000-0000-4000-8000-000000000001',
  '73000000-0000-4000-8000-000000000001',
  '71000000-0000-4000-8000-000000000001',
  '71000000-0000-4000-8000-000000000002'
);

insert into public.messages (
  id, conversation_id, sender_id, message
) values (
  '75000000-0000-4000-8000-000000000001',
  '74000000-0000-4000-8000-000000000001',
  '71000000-0000-4000-8000-000000000002',
  'A private message that must not be copied into notification payloads.'
), (
  '75000000-0000-4000-8000-000000000002',
  '74000000-0000-4000-8000-000000000001',
  '71000000-0000-4000-8000-000000000001',
  'Host reply.'
);

update public.reservations
set status = 'completed', completed_at = now()
where id = '73000000-0000-4000-8000-000000000001';

insert into public.reviews (
  id, reservation_id, reviewer_id, reviewee_id, rating, comment
) values (
  '76000000-0000-4000-8000-000000000001',
  '73000000-0000-4000-8000-000000000001',
  '71000000-0000-4000-8000-000000000002',
  '71000000-0000-4000-8000-000000000001',
  5, 'Private review body'
);

select is(
  (select count(*)::integer from public.notifications
    where user_id = '71000000-0000-4000-8000-000000000001'),
  3,
  'host receives confirmed reservation, driver message, and review events'
);
select is(
  (select count(*)::integer from public.notifications
    where user_id = '71000000-0000-4000-8000-000000000002'),
  1,
  'driver receives the host message event'
);
select ok(
  not exists (
    select 1 from public.notifications
    where data_json ?| array['message', 'comment', 'email', 'total_price']
  ),
  'notification payloads do not duplicate private content or payment totals'
);
select is(
  (select count(*)::integer from public.notifications
    where source_entity_id = '73000000-0000-4000-8000-000000000001'
      and type = 'reservation_confirmed'),
  1,
  'confirmed transition creates exactly one deduplicated event'
);
select ok(notification_tests.query_throws($q$
  insert into public.notifications(
    user_id, actor_user_id, type, source_entity_type, source_entity_id
  ) values (
    '71000000-0000-4000-8000-000000000001',
    '71000000-0000-4000-8000-000000000002',
    'reservation_confirmed', 'reservation',
    '73000000-0000-4000-8000-000000000001'
  )
$q$), 'event dedupe index rejects a duplicate source event');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config(
  'request.jwt.claim.sub',
  '71000000-0000-4000-8000-000000000003',
  true
);
select is(
  (select count(*)::integer from public.notifications),
  0,
  'unrelated user cannot read another user notification feed'
);
select ok(notification_tests.query_throws($q$
  insert into public.notifications(
    user_id, type, source_entity_type, source_entity_id
  ) values (
    '71000000-0000-4000-8000-000000000003',
    'message_received', 'message', gen_random_uuid()
  )
$q$), 'authenticated clients cannot forge notifications');
select ok(notification_tests.query_throws(
  'update public.notifications set is_read=true, read_at=now()'
), 'authenticated clients cannot directly update notification state');
select ok(notification_tests.query_throws(
  'delete from public.notifications'
), 'authenticated clients cannot directly delete notifications');
select is(
  public.mark_notification_read(
    (select id from public.notifications
      where user_id = '71000000-0000-4000-8000-000000000001'
      limit 1)
  ),
  false,
  'narrow read RPC cannot mutate another user notification'
);
select ok(notification_tests.query_throws($q$
  select public.mark_message_notifications_read(
    '73000000-0000-4000-8000-000000000001'
  )
$q$), 'unrelated user cannot consume reservation message notifications');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config(
  'request.jwt.claim.sub',
  '71000000-0000-4000-8000-000000000001',
  true
);
select is(
  (select count(*)::integer from public.notifications),
  3,
  'host RLS exposes only the host feed'
);
select is(
  public.mark_message_notifications_read(
    '73000000-0000-4000-8000-000000000001'
  )::integer,
  1,
  'opening the trip marks only its unread message event'
);
select is(
  public.mark_all_notifications_read()::integer,
  2,
  'mark-all RPC consumes the remaining host events'
);
select ok(
  public.delete_notification(
    (select id from public.notifications order by created_at limit 1)
  ),
  'owner can delete one notification through the narrow RPC'
);
select ok(
  not has_table_privilege('authenticated', 'public.notifications', 'INSERT')
  and not has_table_privilege('authenticated', 'public.notifications', 'UPDATE')
  and not has_table_privilege('authenticated', 'public.notifications', 'DELETE'),
  'authenticated role has no direct notification write privileges'
);
reset role;

set local role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
select set_config('parkd.trusted_write', 'on', true);
insert into public.notifications (
  user_id, type, source_entity_type, source_entity_id, created_at
) values (
  '71000000-0000-4000-8000-000000000001',
  'message_received', 'message',
  '75000000-0000-4000-8000-000000000099',
  now() - interval '31 days'
);
select is(
  public.purge_old_notifications(now() - interval '30 days')::integer,
  1,
  'service retention removes events older than thirty days'
);

insert into public.notifications (
  user_id, type, source_entity_type, source_entity_id, created_at
) values (
  '71000000-0000-4000-8000-000000000001',
  'message_received', 'message',
  '75000000-0000-4000-8000-000000000098',
  now() - interval '31 days'
);
select count(*) from public.purge_expired_demo_data(1, now());
select is(
  (select count(*)::integer from public.notifications
    where source_entity_id = '75000000-0000-4000-8000-000000000098'),
  0,
  'scheduled cleanup RPC automatically applies notification retention'
);

update public.profiles
set deleted_at = now()
where id = '71000000-0000-4000-8000-000000000002';
select is(
  (select count(*)::integer from public.notifications
    where user_id = '71000000-0000-4000-8000-000000000002'
       or actor_user_id = '71000000-0000-4000-8000-000000000002'),
  0,
  'soft deletion removes both inbox and actor-linked events'
);
reset role;

select * from finish();
rollback;
