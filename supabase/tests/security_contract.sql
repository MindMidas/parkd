-- Run with: supabase db reset && supabase test db
-- This suite uses real anon/authenticated/service_role database roles so RLS,
-- grants, SECURITY DEFINER checks, and trigger behavior are exercised together.
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

-- Confirmed fixture users; auth trigger creates their profiles.
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data) values
  ('11111111-1111-4111-8111-111111111111', 'host@example.test', now(),
    '{"username":"host_user","full_name":"Host User"}'::jsonb),
  ('22222222-2222-4222-8222-222222222222', 'driver@example.test', now(),
    '{"username":"driver_user","full_name":"Driver User"}'::jsonb),
  ('33333333-3333-4333-8333-333333333333', 'attacker@example.test', now(),
    '{"username":"attacker_user","full_name":"Attacker User"}'::jsonb),
  ('44444444-4444-4444-8444-444444444444', 'other-driver@example.test', now(),
    '{"username":"other_driver","full_name":"Other Driver"}'::jsonb),
  ('55555555-5555-4555-8555-555555555555', 'admin@example.test', now(),
    '{"username":"parkd_admin","full_name":"Parkd Admin"}'::jsonb);

insert into public.app_admins(user_id)
values ('55555555-5555-4555-8555-555555555555');
select is((select count(*)::integer from public.profiles), 5,
  'confirmed Auth users receive one profile each');

-- Host creates a draft, secured media path, availability, then publishes.
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
insert into public.listings (
  id, host_id, address, city, postal_code, latitude, longitude, availability_mode
) values (
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  '11111111-1111-4111-8111-111111111111',
  '123 Secret Street', 'Guelph', 'N1G 2W1', 43.532456, -80.226789, 'specific'
);
insert into public.availability_specific (
  id, listing_id, start_datetime, end_datetime, price_hour, price_day
) values (
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  date_trunc('day', now()) + interval '3 days',
  date_trunc('day', now()) + interval '4 days', 20, 150
);
insert into public.listing_photos(listing_id, photo_url)
values (
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  '11111111-1111-4111-8111-111111111111/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/hero.jpg'
);
update public.listings set terms_accepted = true, terms_accepted_at = now(),
  is_active = true, is_published = true
where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
select pass('host can assemble and publish a complete listing');

-- An unrelated user sees only the privacy-safe projection.
select set_config('request.jwt.claim.sub', '33333333-3333-4333-8333-333333333333', true);
select is((select count(*)::integer from public.listings
  where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'), 0,
  'unrelated user cannot select exact listing row');
select is((select count(*)::integer from public.public_listing_cards
  where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'), 1,
  'unrelated user can select safe map card');
select is((select count(*)::integer from public.profiles
  where id = '11111111-1111-4111-8111-111111111111'), 0,
  'unrelated user cannot select private profile row');
select is((select count(*)::integer from public.public_profiles
  where id = '11111111-1111-4111-8111-111111111111'), 1,
  'unrelated user can select safe public profile');
select ok(not exists (
  select 1 from information_schema.columns
  where table_schema = 'public' and table_name = 'public_listing_cards'
    and column_name in ('address','spot_number','postal_code','latitude','longitude')
), 'safe listing view has no exact-location columns');
select is((select approximate_latitude from public.public_listing_cards
  where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'), 43.532::double precision,
  'public latitude is reduced to three decimals');
select ok(tests.query_throws($q$
  insert into public.reservations(
    listing_id,driver_id,host_id,start_time,end_time,total_price,service_fee,status,checkout_expires_at
  ) values (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','33333333-3333-4333-8333-333333333333',
    '11111111-1111-4111-8111-111111111111',now()+interval '3 days',now()+interval '3 days 1 hour',
    0.01,0,'pending',now()+interval '15 minutes'
  )$q$), 'client cannot directly insert a reservation');
select ok(tests.query_throws($q$
  insert into public.payments(reservation_id,amount,service_fee) values (gen_random_uuid(),0.01,0)
$q$), 'client cannot directly insert a payment');
select ok(tests.query_throws($q$
  update public.profiles set rating=5 where id='33333333-3333-4333-8333-333333333333'
$q$), 'client cannot tamper with trusted profile rating');
select ok(not has_function_privilege('authenticated',
  'public.is_username_available(text)', 'EXECUTE'),
  'username availability enumeration RPC is not client executable');
select ok(not has_function_privilege('authenticated',
  'public.is_phone_available(text)', 'EXECUTE'),
  'phone availability enumeration RPC is not client executable');
select ok(not has_function_privilege('authenticated',
  'public.create_checkout_session(uuid,timestamptz,timestamptz,text)', 'EXECUTE'),
  'internal checkout helper is not directly client executable');
do $$
declare i integer;
begin
  for i in 1..5 loop
    insert into public.listings(host_id,address,city,latitude,longitude)
    values ('33333333-3333-4333-8333-333333333333','Draft ' || i || ' Test Street',
      'Guelph',43.5 + i / 1000.0,-80.2 - i / 1000.0);
  end loop;
end $$;
select pass('user can create a normal burst of five listing drafts per hour');
select ok(tests.query_throws($q$
  insert into public.listings(host_id,address,city,latitude,longitude)
  values ('33333333-3333-4333-8333-333333333333','Draft 6 Test Street','Guelph',43.51,-80.21)
$q$), 'database rejects listing-creation spam above hourly burst');
reset role;

-- Edge/service-role creates an authoritative, idempotent pending hold.
set local role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
do $$ begin
  perform * from public.prepare_reservation_checkout(
    '22222222-2222-4222-8222-222222222222',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    date_trunc('day', now()) + interval '3 days 10 hours',
    date_trunc('day', now()) + interval '3 days 11 hours',
    null, 'checkout-key-000000000001', 'web'
  );
end $$;
select is((select amount from public.payments limit 1), 20.00::numeric,
  'checkout subtotal is computed from server availability');
select is((select service_fee from public.payments limit 1), 0.70::numeric,
  'checkout fee is computed server-side at 3.5 percent');
select is((select amount_paid from public.reservations limit 1), 20.70::numeric,
  'reservation trusted total matches payment total');
select is((select checkout_platform from public.payments limit 1), 'web',
  'checkout platform is recorded');
select ok(tests.query_throws($q$
  select * from public.prepare_reservation_checkout(
    '44444444-4444-4444-8444-444444444444',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    date_trunc('day', now()) + interval '3 days 10 hours 30 minutes',
    date_trunc('day', now()) + interval '3 days 11 hours 30 minutes',
    null, 'checkout-key-000000000002', 'mobile')
$q$), 'database exclusion constraint prevents overlapping checkout holds');
do $$ begin
  perform * from public.prepare_reservation_checkout(
    '22222222-2222-4222-8222-222222222222',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    date_trunc('day', now()) + interval '3 days 10 hours',
    date_trunc('day', now()) + interval '3 days 11 hours',
    null, 'checkout-key-000000000001', 'web'
  );
end $$;
select is((select count(*)::integer from public.reservations), 1,
  'same idempotency key returns the original checkout');
select ok(tests.query_throws($q$
  select * from public.prepare_reservation_checkout(
    '22222222-2222-4222-8222-222222222222',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    date_trunc('day', now()) + interval '3 days 10 hours',
    date_trunc('day', now()) + interval '3 days 11 hours',
    null, 'checkout-key-000000000001', 'mobile')
$q$), 'idempotent retry cannot switch checkout platform');
select set_config('parkd.trusted_write', 'off', true);
select set_config('parkd.checkout_user_id', '', true);
reset role;

-- Pending holds block availability but do not unlock the exact address.
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
select is((select count(*)::integer from public.listings
  where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'), 0,
  'pending driver cannot read exact address');
select is((select count(*)::integer from public.public_listing_busy_windows
  where listing_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'), 1,
  'public busy-window view includes a live checkout hold');
select ok(tests.query_throws('update public.payments set amount=0.01'),
  'driver cannot tamper with payment amount');
select ok(tests.query_throws('update public.reservations set status=''confirmed'''),
  'driver cannot forge reservation state');
select ok(public.cancel_checkout_hold((select id from public.reservations), 'terms_declined'),
  'driver can safely cancel their own pending hold');
select is((select status::text from public.payments limit 1), 'failed',
  'cancelling hold atomically fails linked pending payment');
reset role;

-- Create a new hold after cancellation and finalize through verified Stripe event.
set local role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
do $$ begin
  perform * from public.prepare_reservation_checkout(
    '22222222-2222-4222-8222-222222222222',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    date_trunc('day', now()) + interval '3 days 10 hours',
    date_trunc('day', now()) + interval '3 days 11 hours',
    null, 'checkout-key-000000000003', 'web'
  );
end $$;
select ok(public.record_checkout_session(
  (select id from public.payments where status='pending'), 'cs_test_security001'),
  'service records test Checkout Session');
select ok(public.record_checkout_payment_intent(
  (select id from public.payments where status='pending'), 'pi_security001'),
  'service binds PaymentIntent to trusted payment');
select ok((select processed from public.process_stripe_webhook_event(
  'evt_security001', 'checkout.session.completed', 'pi_security001',
  'cs_test_security001', 'succeeded', 2070, 'cad', now()
)), 'verified Checkout webhook is processed');
select ok(not (select processed from public.process_stripe_webhook_event(
  'evt_security001', 'checkout.session.completed', 'pi_security001',
  'cs_test_security001', 'succeeded', 2070, 'cad', now()
)), 'duplicate Stripe event is idempotently ignored');
select is((select status::text from public.reservations where status='confirmed'),
  'confirmed', 'successful payment confirms reservation atomically');
select is((select count(*)::integer from public.conversations), 1,
  'payment success creates exactly one reservation conversation');
select set_config('parkd.trusted_write', 'off', true);
select set_config('parkd.checkout_user_id', '', true);
reset role;

-- Confirmation unlocks the exact location to the driver, but not to an attacker.
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
select is((select address from public.listings
  where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'), '123 Secret Street',
  'confirmed driver can read exact address');
select is((select count(*)::integer from public.host_earnings), 0,
  'driver cannot read host earnings aggregate');
select is((select count(*)::integer from public.profiles
  where id='11111111-1111-4111-8111-111111111111'), 0,
  'reservation participant still cannot read host PII row');
insert into public.messages(conversation_id, sender_id, message)
select id, '22222222-2222-4222-8222-222222222222', 'Hello host' from public.conversations;
select pass('conversation participant can send a bounded message');
update public.messages set status='read';
select is((select min(status::text) from public.messages), 'sent',
  'message sender cannot mark their own message read');
do $$
declare i integer;
begin
  for i in 1..29 loop
    insert into public.messages(conversation_id,sender_id,message)
    select id,'22222222-2222-4222-8222-222222222222','burst ' || i
    from public.conversations;
  end loop;
end $$;
select pass('normal chat burst up to thirty messages per minute is accepted');
select ok(tests.query_throws($q$
  insert into public.messages(conversation_id,sender_id,message)
  select id,'22222222-2222-4222-8222-222222222222','burst rejected'
  from public.conversations
$q$), 'database rejects message spam above per-minute burst');

select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
update public.messages set status='read';
select ok((select bool_and(read_at is not null) from public.messages),
  'only recipient marks message read and read_at is server-stamped');
select ok(public.set_user_block('22222222-2222-4222-8222-222222222222', true),
  'user can block another participant');

select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
select ok(tests.query_throws($q$
  insert into public.messages(conversation_id,sender_id,message)
  select id,'22222222-2222-4222-8222-222222222222','blocked' from public.conversations
$q$), 'either-direction user block prevents further messages');
select is((select count(*)::integer from public.public_listing_cards
  where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'), 0,
  'blocked relationship filters public listing cards');

select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select ok(public.submit_report('user',
  '33333333-3333-4333-8333-333333333333','spam','automated security test') is not null,
  'authenticated user can submit structured report');
select ok(tests.query_throws($q$
  select public.submit_report('user','11111111-1111-4111-8111-111111111111','other','self')
$q$), 'user cannot report themselves');
select is((select count(*)::integer from public.moderation_queue), 0,
  'non-admin cannot read moderation queue');
reset role;

-- Complete reservation lifecycle and enforce two-sided review integrity.
set local role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
select public.advance_reservation_lifecycle(date_trunc('day',now()) + interval '4 days');
select is((select status::text from public.reservations where status='completed'),
  'completed', 'lifecycle worker completes ended reservation');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
insert into public.reviews(reservation_id,reviewer_id,reviewee_id,rating,comment)
select id,'22222222-2222-4222-8222-222222222222',
  '11111111-1111-4111-8111-111111111111',5,'Great host'
from public.reservations where status='completed';
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select is((select rating_count from public.profiles
  where id='11111111-1111-4111-8111-111111111111'), 1,
  'valid completed-reservation review updates aggregate rating');
select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
select ok(tests.query_throws($q$
  insert into public.reviews(reservation_id,reviewer_id,reviewee_id,rating)
  select id,'22222222-2222-4222-8222-222222222222',
    '11111111-1111-4111-8111-111111111111',4 from public.reservations where status='completed'
$q$), 'same participant cannot review a reservation twice');
reset role;

-- Storage writes are owner/path/MIME/size constrained while public media buckets
-- remain compatible with getPublicUrl().
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
insert into storage.objects(bucket_id,name,metadata) values (
  'listing-photos',
  '11111111-1111-4111-8111-111111111111/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/upload.jpg',
  '{"mimetype":"image/jpeg","size":1000}'::jsonb
);
select pass('listing owner can upload valid image object');

select set_config('request.jwt.claim.sub', '33333333-3333-4333-8333-333333333333', true);
select ok(tests.query_throws($q$
  insert into storage.objects(bucket_id,name,metadata) values (
    'listing-photos',
    '33333333-3333-4333-8333-333333333333/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/attack.jpg',
    '{"mimetype":"image/jpeg","size":1000}'::jsonb)
$q$), 'non-owner cannot upload into listing media path');
select ok(tests.query_throws($q$
  insert into storage.objects(bucket_id,name,metadata) values (
    'avatars','33333333-3333-4333-8333-333333333333/payload.svg',
    '{"mimetype":"image/svg+xml","size":1000}'::jsonb)
$q$), 'disallowed storage MIME and extension are rejected');
reset role;
select ok((select bool_and(public) from storage.buckets
  where id in ('listing-photos','avatars')),
  'media buckets support public read URLs');

-- Moderation queue and state transitions are admin-only.
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '55555555-5555-4555-8555-555555555555', true);
select is((select count(*)::integer from public.moderation_queue), 1,
  'admin can read moderation queue');
update public.reports set status='reviewing', moderator_notes='triaged';
select is((select status::text from public.reports), 'reviewing',
  'admin can advance valid moderation state');
select ok(tests.query_throws('update public.reports set status=''open'''),
  'moderation state cannot move backwards');
reset role;

-- Soft deletion, account cleanup metadata, and rate limits.
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select ok(public.soft_delete_listing('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  'host soft-deletes listing after live reservations end');
select is((select count(*)::integer from public.public_listing_cards
  where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'), 0,
  'soft-deleted listing disappears from discovery');
select set_config('parkd.trusted_write', 'off', true);
reset role;

select set_config('request.jwt.claim.role', 'service_role', true);
update public.profiles set stripe_customer_id='cus_test_attacker'
where id='33333333-3333-4333-8333-333333333333';
set local role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
select is((public.prepare_account_deletion(
  '33333333-3333-4333-8333-333333333333')->>'stripe_customer_id'),
  'cus_test_attacker', 'account deletion returns Stripe customer for Edge cleanup');
select ok((select deleted_at is not null and email is null and phone is null
  from public.profiles where id='33333333-3333-4333-8333-333333333333'),
  'account deletion anonymizes PII while retaining profile key');
select ok(public.complete_account_deletion(
  '33333333-3333-4333-8333-333333333333'),
  'interactive Edge cleanup records completion');
select is((select count(*)::integer
  from public.claim_account_deletion_jobs(25, now())), 0,
  'completed account deletion is not returned for reconciliation');
select ok(public.consume_rate_limit('payments', repeat('a',64), 2, 60),
  'first distributed rate-limit request is accepted');
select ok(public.consume_rate_limit('payments', repeat('a',64), 2, 60),
  'request at configured limit is accepted');
select ok(not public.consume_rate_limit('payments', repeat('a',64), 2, 60),
  'request above configured limit is rejected');
reset role;

select * from finish();
rollback;
