-- Server-authoritative booking, payment integrity, lifecycle, and privacy.
-- The baseline migration is an immutable snapshot of supabase/schema.sql.

-- Read the JWT role consistently in direct Postgres tests and through PostgREST.
create or replace function public.request_jwt_role()
returns text
language sql
stable
as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role',
    current_user
  );
$$;

create or replace function public.is_service_role()
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select public.request_jwt_role() in ('service_role', 'supabase_admin', 'postgres');
$$;

revoke all on function public.is_service_role() from public;
grant execute on function public.is_service_role() to anon, authenticated, service_role;

create or replace function public.is_trusted_write()
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select public.is_service_role()
    or current_setting('parkd.trusted_write', true) = 'on';
$$;

revoke all on function public.is_trusted_write() from public;
grant execute on function public.is_trusted_write() to anon, authenticated, service_role;

-- Soft deletion and demo-account expiry preserve the financial audit trail.
alter table public.profiles
  add column if not exists is_demo boolean not null default true,
  add column if not exists demo_expires_at timestamptz default (now() + interval '24 hours'),
  add column if not exists deleted_at timestamptz,
  add column if not exists deletion_requested_at timestamptz;

alter table public.listings
  add column if not exists timezone text not null default 'America/Toronto',
  add column if not exists deleted_at timestamptz;

alter table public.reservations
  add column if not exists checkout_expires_at timestamptz,
  add column if not exists cancelled_at timestamptz,
  add column if not exists cancellation_reason text,
  add column if not exists completed_at timestamptz;

alter table public.payments
  add column if not exists currency text not null default 'cad',
  add column if not exists checkout_platform text not null default 'mobile',
  add column if not exists stripe_checkout_session_id text,
  add column if not exists last_stripe_event_created timestamptz,
  add column if not exists reconciliation_required boolean not null default false;

create unique index if not exists payments_stripe_checkout_session_unique
  on public.payments (stripe_checkout_session_id)
  where stripe_checkout_session_id is not null;

alter table public.payments drop constraint if exists payments_currency_check;
alter table public.payments add constraint payments_currency_check
  check (currency = lower(currency) and currency ~ '^[a-z]{3}$');
alter table public.payments drop constraint if exists payments_checkout_platform_check;
alter table public.payments add constraint payments_checkout_platform_check
  check (checkout_platform in ('mobile', 'web'));

alter table public.reservations drop constraint if exists reservations_checkout_expiry_check;
alter table public.reservations add constraint reservations_checkout_expiry_check
  check (
    status <> 'pending'
    or (checkout_expires_at is not null and checkout_expires_at > created_at)
  ) not valid;

create index if not exists profiles_demo_expiry_idx
  on public.profiles (demo_expires_at)
  where is_demo and deleted_at is null;
create index if not exists listings_not_deleted_idx
  on public.listings (is_active, is_published)
  where deleted_at is null;
create index if not exists reservations_checkout_expiry_idx
  on public.reservations (checkout_expires_at)
  where status = 'pending';

-- Only the auth trigger/service role can change identity, trust, and expiry fields.
create or replace function public.guard_profile_trusted_fields()
returns trigger
language plpgsql
set search_path = public, pg_catalog
as $$
begin
  if public.is_trusted_write() then
    return new;
  end if;

  if new.id is distinct from old.id
    or new.email is distinct from old.email
    or new.rating is distinct from old.rating
    or new.rating_count is distinct from old.rating_count
    or new.stripe_customer_id is distinct from old.stripe_customer_id
    or new.is_demo is distinct from old.is_demo
    or new.demo_expires_at is distinct from old.demo_expires_at
    or new.deleted_at is distinct from old.deleted_at
    or new.deletion_requested_at is distinct from old.deletion_requested_at
  then
    raise exception using errcode = '42501', message = 'PROFILE_TRUSTED_FIELDS_SERVER_ONLY';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_profiles_trusted_fields_guard on public.profiles;
create trigger trg_profiles_trusted_fields_guard
before update on public.profiles
for each row execute function public.guard_profile_trusted_fields();

create or replace function public.validate_listing_timezone()
returns trigger
language plpgsql
set search_path = public, pg_catalog
as $$
begin
  if not exists (select 1 from pg_timezone_names where name = new.timezone) then
    raise exception using errcode = '22023', message = 'INVALID_LISTING_TIMEZONE';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_listings_timezone_guard on public.listings;
create trigger trg_listings_timezone_guard
before insert or update of timezone on public.listings
for each row execute function public.validate_listing_timezone();

-- Clients may never forge trusted reservation/payment rows. Creation happens through
-- create_checkout_session and Stripe state changes happen through service-only RPCs.
drop policy if exists "reservations_driver_insert" on public.reservations;
drop policy if exists "payments_driver_insert" on public.payments;
drop policy if exists "payments_update_participants" on public.payments;
drop policy if exists "payment_methods_insert_own" on public.payment_methods;

revoke insert on public.reservations from anon, authenticated;
revoke insert, update on public.payments from anon, authenticated;
revoke insert on public.payment_methods from anon, authenticated;

create or replace function public.prevent_untrusted_reservation_updates()
returns trigger
language plpgsql
set search_path = public, pg_catalog
as $$
begin
  if public.is_trusted_write() then
    return new;
  end if;

  if tg_op = 'INSERT' then
    raise exception using errcode = '42501', message = 'RESERVATIONS_RPC_ONLY';
  end if;

  if new.listing_id is distinct from old.listing_id
    or new.driver_id is distinct from old.driver_id
    or new.host_id is distinct from old.host_id
    or new.start_time is distinct from old.start_time
    or new.end_time is distinct from old.end_time
    or new.total_price is distinct from old.total_price
    or new.service_fee is distinct from old.service_fee
    or new.checkout_expires_at is distinct from old.checkout_expires_at
    or new.extended_from_reservation_id is distinct from old.extended_from_reservation_id
    or new.completed_at is distinct from old.completed_at
  then
    raise exception using errcode = '42501', message = 'RESERVATION_TRUSTED_FIELDS_SERVER_ONLY';
  end if;

  if new.status is distinct from old.status then
    if new.status <> 'cancelled' or old.status not in ('pending', 'confirmed', 'active') then
      raise exception using errcode = '42501', message = 'RESERVATION_STATUS_SERVER_ONLY';
    end if;
    new.cancelled_at := coalesce(new.cancelled_at, now());
    new.cancellation_reason := left(coalesce(nullif(trim(new.cancellation_reason), ''), 'cancelled_by_participant'), 240);
  elsif new.cancelled_at is distinct from old.cancelled_at
    or new.cancellation_reason is distinct from old.cancellation_reason
  then
    raise exception using errcode = '42501', message = 'RESERVATION_CANCELLATION_FIELDS_WITH_STATUS_ONLY';
  end if;

  return new;
end;
$$;

create or replace function public.prevent_untrusted_payment_changes()
returns trigger
language plpgsql
set search_path = public, pg_catalog
as $$
begin
  if public.is_trusted_write() then
    return new;
  end if;
  raise exception using errcode = '42501', message = 'PAYMENTS_SERVER_ONLY';
end;
$$;

-- Pending checkout rows are short-lived holds. Including them in the exclusion
-- constraint prevents two PaymentIntents from being created for the same space/time.
alter table public.reservations drop constraint if exists reservations_no_live_overlap;
alter table public.reservations add constraint reservations_no_checkout_overlap
  exclude using gist (
    listing_id with =,
    tstzrange(start_time, end_time, '[)') with &&
  )
  where (status in ('pending', 'confirmed', 'active'));

drop trigger if exists trg_reservations_live_overlap_guard on public.reservations;

-- Match the client display rules, but make this implementation authoritative.
create or replace function public.hourly_price_for_minutes(
  p_minutes integer,
  p_hourly numeric
)
returns numeric
language plpgsql
immutable
strict
set search_path = pg_catalog
as $$
declare
  v_hours integer;
  v_remainder integer;
  v_tail numeric := 0;
begin
  if p_minutes <= 0 or p_hourly < 0 then return 0; end if;
  if p_minutes < 60 then
    return ceil(greatest(10, p_minutes)::numeric / 10) * p_hourly / 6;
  end if;
  v_hours := p_minutes / 60;
  v_remainder := p_minutes % 60;
  if v_remainder > 0 then
    v_tail := ceil(greatest(10, v_remainder)::numeric / 10) * p_hourly / 6;
  end if;
  return (v_hours * p_hourly) + v_tail;
end;
$$;

create or replace function public.authoritative_reservation_subtotal(
  p_minutes integer,
  p_hourly numeric,
  p_daily numeric
)
returns numeric
language plpgsql
immutable
set search_path = public, pg_catalog
as $$
declare
  v_minutes integer := greatest(10, p_minutes);
  v_hourly numeric;
  v_daily numeric;
  v_days integer;
  v_remainder integer;
begin
  if p_minutes <= 0 or p_hourly is null or p_hourly < 0 then return 0; end if;
  v_hourly := public.hourly_price_for_minutes(v_minutes, p_hourly);
  if v_minutes > 1440 and coalesce(p_daily, 0) > 0 then
    v_days := v_minutes / 1440;
    v_remainder := v_minutes % 1440;
    v_daily := (v_days * p_daily)
      + case when v_remainder = 0 then 0
             else public.hourly_price_for_minutes(greatest(10, v_remainder), p_hourly)
        end;
    return round(least(v_hourly, v_daily), 2);
  end if;
  return round(v_hourly, 2);
end;
$$;

create table if not exists public.checkout_idempotency (
  driver_id uuid not null references public.profiles(id) on delete restrict,
  idempotency_key text not null,
  reservation_id uuid not null unique references public.reservations(id) on delete restrict,
  payment_id uuid not null unique references public.payments(id) on delete restrict,
  checkout_platform text,
  created_at timestamptz not null default now(),
  primary key (driver_id, idempotency_key),
  constraint checkout_idempotency_key_check
    check (char_length(idempotency_key) between 16 and 128 and idempotency_key ~ '^[A-Za-z0-9._:-]+$'),
  constraint checkout_idempotency_platform_check
    check (checkout_platform is null or checkout_platform in ('mobile', 'web'))
);

alter table public.checkout_idempotency enable row level security;
revoke all on public.checkout_idempotency from anon, authenticated;

create or replace function public.create_checkout_session(
  p_listing_id uuid,
  p_start_time timestamptz,
  p_end_time timestamptz,
  p_idempotency_key text
)
returns table (
  reservation_id uuid,
  payment_id uuid,
  amount_cents bigint,
  currency text,
  checkout_expires_at timestamptz,
  reservation_status public.reservation_status
)
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_driver_id uuid := coalesce(
    nullif(current_setting('parkd.checkout_user_id', true), '')::uuid,
    auth.uid()
  );
  v_host_id uuid;
  v_mode public.availability_mode;
  v_timezone text;
  v_hourly numeric(10,2);
  v_daily numeric(10,2);
  v_minutes integer;
  v_subtotal numeric(10,2);
  v_fee numeric(10,2);
  v_reservation_id uuid;
  v_payment_id uuid;
  v_expiry timestamptz;
  v_existing record;
  v_local_start timestamp;
  v_local_end timestamp;
begin
  if v_driver_id is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;
  perform set_config('parkd.trusted_write', 'on', true);
  if not exists (
    select 1 from public.profiles p
    where p.id = v_driver_id and p.deleted_at is null
      and (not p.is_demo or p.demo_expires_at > now())
  ) then
    raise exception using errcode = '42501', message = 'ACTIVE_PROFILE_REQUIRED';
  end if;
  p_idempotency_key := trim(p_idempotency_key);
  if char_length(p_idempotency_key) not between 16 and 128
    or p_idempotency_key !~ '^[A-Za-z0-9._:-]+$' then
    raise exception using errcode = '22023', message = 'INVALID_IDEMPOTENCY_KEY';
  end if;
  if p_end_time <= p_start_time or p_start_time < now() - interval '1 minute'
    or p_end_time > now() + interval '366 days' then
    raise exception using errcode = '22023', message = 'INVALID_RESERVATION_WINDOW';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_driver_id::text || ':' || p_idempotency_key, 0));
  select ci.reservation_id, ci.payment_id, r.amount_paid, p.currency, r.checkout_expires_at, r.status
    into v_existing
  from public.checkout_idempotency ci
  join public.reservations r on r.id = ci.reservation_id
  join public.payments p on p.id = ci.payment_id
  where ci.driver_id = v_driver_id and ci.idempotency_key = p_idempotency_key;
  if found then
    return query select v_existing.reservation_id, v_existing.payment_id,
      round(v_existing.amount_paid * 100)::bigint, v_existing.currency,
      v_existing.checkout_expires_at, v_existing.status;
    return;
  end if;

  -- Release abandoned holds before taking the listing lock.
  update public.reservations r
     set status = 'cancelled', cancelled_at = now(), cancellation_reason = 'checkout_expired'
   where r.status = 'pending' and r.checkout_expires_at <= now();
  update public.payments p
     set status = 'failed'
   where p.status = 'pending'
     and exists (select 1 from public.reservations r where r.id = p.reservation_id and r.status = 'cancelled' and r.cancellation_reason = 'checkout_expired');

  select l.host_id, l.availability_mode, l.timezone
    into v_host_id, v_mode, v_timezone
  from public.listings l
  where l.id = p_listing_id and l.is_active and l.is_published and l.deleted_at is null
  for share;
  if not found then
    raise exception using errcode = 'P0002', message = 'LISTING_NOT_AVAILABLE';
  end if;
  if v_host_id = v_driver_id then
    raise exception using errcode = '22023', message = 'CANNOT_RESERVE_OWN_LISTING';
  end if;

  if v_mode = 'specific' then
    select s.price_hour, s.price_day into v_hourly, v_daily
    from public.availability_specific s
    where s.listing_id = p_listing_id
      and s.start_datetime <= p_start_time and s.end_datetime >= p_end_time
    order by s.start_datetime desc limit 1;
  else
    v_local_start := p_start_time at time zone v_timezone;
    v_local_end := p_end_time at time zone v_timezone;
    if v_local_start::date = v_local_end::date then
      select w.price_hour, w.price_day into v_hourly, v_daily
      from public.availability_weekly w
      where w.listing_id = p_listing_id
        and w.day_of_week = extract(dow from v_local_start)::integer
        and w.start_time <= v_local_start::time
        and w.end_time >= v_local_end::time
      order by w.start_time desc limit 1;
    end if;
  end if;
  if v_hourly is null then
    raise exception using errcode = '22023', message = 'WINDOW_OUTSIDE_AVAILABILITY';
  end if;

  v_minutes := floor(extract(epoch from (p_end_time - p_start_time)) / 60)::integer;
  v_subtotal := public.authoritative_reservation_subtotal(v_minutes, v_hourly, v_daily);
  v_fee := round(v_subtotal * 0.035, 2);
  if v_subtotal <= 0 then
    raise exception using errcode = '22023', message = 'INVALID_AUTHORITATIVE_PRICE';
  end if;
  v_expiry := now() + interval '15 minutes';

  insert into public.reservations (
    listing_id, driver_id, host_id, start_time, end_time,
    total_price, service_fee, status, checkout_expires_at
  ) values (
    p_listing_id, v_driver_id, v_host_id, p_start_time, p_end_time,
    v_subtotal, v_fee, 'pending', v_expiry
  ) returning id into v_reservation_id;

  insert into public.payments (reservation_id, amount, service_fee, status, currency)
  values (v_reservation_id, v_subtotal, v_fee, 'pending', 'cad')
  returning id into v_payment_id;

  insert into public.checkout_idempotency (driver_id, idempotency_key, reservation_id, payment_id)
  values (v_driver_id, p_idempotency_key, v_reservation_id, v_payment_id);

  return query select v_reservation_id, v_payment_id,
    round((v_subtotal + v_fee) * 100)::bigint, 'cad'::text,
    v_expiry, 'pending'::public.reservation_status;
end;
$$;

revoke all on function public.create_checkout_session(uuid, timestamptz, timestamptz, text) from public;

-- Edge-facing checkout contract. The service-role caller supplies the user id it
-- obtained from auth.getUser(); no client-supplied price is accepted.
create or replace function public.prepare_reservation_checkout(
  p_user_id uuid,
  p_listing_id uuid,
  p_start_time timestamptz,
  p_end_time timestamptz,
  p_payment_method_id uuid,
  p_idempotency_key text,
  p_platform text
)
returns table (
  reservation_id uuid,
  payment_id uuid,
  subtotal_cents bigint,
  service_fee_cents bigint,
  amount_cents bigint,
  currency text,
  stripe_payment_intent_id text,
  stripe_checkout_session_id text,
  stripe_payment_method_id text
)
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_checkout record;
  v_payment public.payments%rowtype;
  v_stripe_payment_method_id text;
begin
  if not public.is_service_role() then
    raise exception using errcode = '42501', message = 'SERVICE_ROLE_REQUIRED';
  end if;
  p_platform := lower(trim(p_platform));
  if p_platform not in ('mobile', 'web') then
    raise exception using errcode = '22023', message = 'INVALID_CHECKOUT_PLATFORM';
  end if;
  if p_payment_method_id is not null then
    select pm.stripe_payment_method_id into v_stripe_payment_method_id
    from public.payment_methods pm
    where pm.id = p_payment_method_id and pm.user_id = p_user_id;
    if not found then
      raise exception using errcode = '42501', message = 'PAYMENT_METHOD_NOT_OWNED';
    end if;
  end if;

  perform set_config('parkd.trusted_write', 'on', true);
  perform set_config('parkd.checkout_user_id', p_user_id::text, true);
  select * into v_checkout
  from public.create_checkout_session(
    p_listing_id, p_start_time, p_end_time, p_idempotency_key
  );

  if v_checkout.reservation_status <> 'pending' then
    raise exception using errcode = '55000', message = 'CHECKOUT_NOT_PENDING';
  end if;
  if v_checkout.checkout_expires_at <= now() then
    raise exception using errcode = '55000', message = 'CHECKOUT_EXPIRED';
  end if;

  update public.checkout_idempotency ci
    set checkout_platform = p_platform
  where ci.payment_id = v_checkout.payment_id
    and (ci.checkout_platform is null or ci.checkout_platform = p_platform);
  if not found then
    raise exception using errcode = '23505', message = 'IDEMPOTENCY_PLATFORM_MISMATCH';
  end if;

  update public.payments
    set payment_method_id = coalesce(payment_method_id, p_payment_method_id),
        checkout_platform = p_platform
  where id = v_checkout.payment_id
    and (payment_method_id is null or payment_method_id = p_payment_method_id)
  returning * into v_payment;
  if not found then
    raise exception using errcode = '23505', message = 'IDEMPOTENCY_PAYMENT_METHOD_MISMATCH';
  end if;

  return query select
    v_checkout.reservation_id,
    v_checkout.payment_id,
    round(v_payment.amount * 100)::bigint,
    round(v_payment.service_fee * 100)::bigint,
    round((v_payment.amount + v_payment.service_fee) * 100)::bigint,
    v_payment.currency,
    v_payment.stripe_payment_intent_id,
    v_payment.stripe_checkout_session_id,
    v_stripe_payment_method_id;
end;
$$;

revoke all on function public.prepare_reservation_checkout(uuid, uuid, timestamptz, timestamptz, uuid, text, text) from public;
grant execute on function public.prepare_reservation_checkout(uuid, uuid, timestamptz, timestamptz, uuid, text, text) to service_role;

-- Bind the exact Stripe PaymentIntent to the trusted payment row. Edge Functions call
-- this with the service-role client after Stripe creates/retrieves the intent.
create or replace function public.bind_checkout_payment_intent(
  p_payment_id uuid,
  p_stripe_payment_intent_id text,
  p_payment_method_id uuid default null
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_driver_id uuid;
begin
  if not public.is_service_role() then
    raise exception using errcode = '42501', message = 'SERVICE_ROLE_REQUIRED';
  end if;
  if p_stripe_payment_intent_id !~ '^pi_[A-Za-z0-9]+$' then
    raise exception using errcode = '22023', message = 'INVALID_PAYMENT_INTENT_ID';
  end if;
  select r.driver_id into v_driver_id
  from public.payments p join public.reservations r on r.id = p.reservation_id
  where p.id = p_payment_id and p.status = 'pending'
    and r.status = 'pending' and r.checkout_expires_at > now()
  for update of p;
  if not found then
    raise exception using errcode = '55000', message = 'CHECKOUT_NOT_PENDING_OR_EXPIRED';
  end if;
  if p_payment_method_id is not null and not exists (
    select 1 from public.payment_methods pm
    where pm.id = p_payment_method_id and pm.user_id = v_driver_id
  ) then
    raise exception using errcode = '42501', message = 'PAYMENT_METHOD_NOT_OWNED';
  end if;
  update public.payments
    set stripe_payment_intent_id = p_stripe_payment_intent_id,
        payment_method_id = coalesce(p_payment_method_id, payment_method_id)
  where id = p_payment_id
    and (stripe_payment_intent_id is null or stripe_payment_intent_id = p_stripe_payment_intent_id);
  if not found then
    raise exception using errcode = '23505', message = 'PAYMENT_INTENT_BINDING_MISMATCH';
  end if;
  return true;
end;
$$;

revoke all on function public.bind_checkout_payment_intent(uuid, text, uuid) from public;
grant execute on function public.bind_checkout_payment_intent(uuid, text, uuid) to service_role;

create or replace function public.record_checkout_payment_intent(
  p_payment_id uuid,
  p_payment_intent_id text
)
returns boolean
language sql
security definer
set search_path = public, pg_catalog
as $$
  select public.bind_checkout_payment_intent(p_payment_id, p_payment_intent_id, null);
$$;

revoke all on function public.record_checkout_payment_intent(uuid, text) from public;
grant execute on function public.record_checkout_payment_intent(uuid, text) to service_role;

create or replace function public.record_checkout_session(
  p_payment_id uuid,
  p_checkout_session_id text
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if not public.is_service_role() then
    raise exception using errcode = '42501', message = 'SERVICE_ROLE_REQUIRED';
  end if;
  if p_checkout_session_id !~ '^cs_test_[A-Za-z0-9]+$' then
    raise exception using errcode = '22023', message = 'INVALID_CHECKOUT_SESSION_ID';
  end if;
  if not exists (
    select 1 from public.reservations r join public.payments p on p.reservation_id = r.id
    where p.id = p_payment_id and p.status = 'pending'
      and r.status = 'pending' and r.checkout_expires_at > now()
  ) then
    raise exception using errcode = '55000', message = 'CHECKOUT_NOT_PENDING_OR_EXPIRED';
  end if;
  update public.payments
    set stripe_checkout_session_id = p_checkout_session_id
  where id = p_payment_id and status = 'pending'
    and (stripe_checkout_session_id is null or stripe_checkout_session_id = p_checkout_session_id);
  if not found then
    raise exception using errcode = '23505', message = 'CHECKOUT_SESSION_BINDING_MISMATCH';
  end if;
  return true;
end;
$$;

revoke all on function public.record_checkout_session(uuid, text) from public;
grant execute on function public.record_checkout_session(uuid, text) to service_role;

create table if not exists public.stripe_webhook_events (
  event_id text primary key,
  event_type text not null default 'payment_intent.unknown',
  payment_intent_id text not null,
  event_status text not null,
  event_created timestamptz not null,
  processed_at timestamptz not null default now(),
  outcome text not null,
  constraint stripe_webhook_event_id_check check (event_id ~ '^evt_[A-Za-z0-9]+$'),
  constraint stripe_webhook_intent_id_check check (payment_intent_id ~ '^pi_[A-Za-z0-9]+$')
);

alter table public.stripe_webhook_events enable row level security;
revoke all on public.stripe_webhook_events from anon, authenticated;

create or replace function public.finalize_stripe_payment(
  p_event_id text,
  p_payment_intent_id text,
  p_status text,
  p_amount_received bigint,
  p_currency text,
  p_event_created timestamptz
)
returns table (
  processed boolean,
  payment_id uuid,
  reservation_id uuid,
  payment_status public.payment_status,
  reservation_status public.reservation_status,
  reason text
)
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_payment public.payments%rowtype;
  v_reservation public.reservations%rowtype;
  v_expected bigint;
  v_outcome text;
begin
  if not public.is_service_role() then
    raise exception using errcode = '42501', message = 'SERVICE_ROLE_REQUIRED';
  end if;
  p_status := lower(trim(p_status));
  p_currency := lower(trim(p_currency));
  if p_status not in ('succeeded', 'failed', 'canceled') then
    raise exception using errcode = '22023', message = 'UNSUPPORTED_STRIPE_STATUS';
  end if;

  if exists (select 1 from public.stripe_webhook_events e where e.event_id = p_event_id) then
    select * into v_payment from public.payments p
      where p.stripe_payment_intent_id = p_payment_intent_id;
    if found then
      select * into v_reservation from public.reservations r
        where r.id = v_payment.reservation_id;
    end if;
    return query select false, v_payment.id, v_reservation.id, v_payment.status,
      v_reservation.status, 'duplicate_event'::text;
    return;
  end if;

  select * into v_payment from public.payments
  where stripe_payment_intent_id = p_payment_intent_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'PAYMENT_INTENT_NOT_BOUND';
  end if;
  select * into v_reservation from public.reservations
  where id = v_payment.reservation_id for update;

  if v_payment.last_stripe_event_created is not null
    and p_event_created < v_payment.last_stripe_event_created then
    v_outcome := 'stale_event';
  elsif p_status = 'succeeded' and v_payment.status = 'succeeded'
    and v_reservation.status in ('confirmed', 'active', 'completed') then
    update public.payments set last_stripe_event_created = greatest(
      coalesce(last_stripe_event_created, p_event_created), p_event_created
    ) where id = v_payment.id;
    v_outcome := 'already_succeeded';
  elsif p_status = 'succeeded' then
    v_expected := round((v_payment.amount + v_payment.service_fee) * 100)::bigint;
    if p_currency <> v_payment.currency or p_amount_received <> v_expected then
      update public.payments set reconciliation_required = true,
        last_stripe_event_created = p_event_created where id = v_payment.id;
      v_outcome := 'amount_or_currency_mismatch';
    elsif v_reservation.status = 'pending' and v_reservation.checkout_expires_at > now() then
      update public.payments set status = 'succeeded',
        last_stripe_event_created = p_event_created where id = v_payment.id;
      update public.reservations set status = 'confirmed', checkout_expires_at = null
        where id = v_reservation.id;
      insert into public.conversations (reservation_id, host_id, driver_id)
        values (v_reservation.id, v_reservation.host_id, v_reservation.driver_id)
        on conflict on constraint conversations_reservation_id_key do nothing;
      v_outcome := 'succeeded';
    else
      update public.payments set status = 'succeeded', reconciliation_required = true,
        last_stripe_event_created = p_event_created where id = v_payment.id;
      if v_reservation.status = 'pending' then
        update public.reservations set status = 'cancelled', cancelled_at = now(),
          cancellation_reason = 'stripe_succeeded_after_expiry'
        where id = v_reservation.id;
      end if;
      v_outcome := 'reservation_not_confirmable';
    end if;
  else
    if v_payment.status = 'pending' then
      update public.payments set status = 'failed',
        last_stripe_event_created = p_event_created where id = v_payment.id;
    end if;
    if v_reservation.status = 'pending' then
      update public.reservations set status = 'cancelled', cancelled_at = now(),
        cancellation_reason = 'stripe_' || p_status where id = v_reservation.id;
    end if;
    v_outcome := p_status;
  end if;

  insert into public.stripe_webhook_events (
    event_id, payment_intent_id, event_status, event_created, outcome
  ) values (p_event_id, p_payment_intent_id, p_status, p_event_created, v_outcome);

  select * into v_payment from public.payments where id = v_payment.id;
  select * into v_reservation from public.reservations where id = v_reservation.id;
  return query select true, v_payment.id, v_reservation.id, v_payment.status,
    v_reservation.status, v_outcome;
end;
$$;

revoke all on function public.finalize_stripe_payment(text, text, text, bigint, text, timestamptz) from public;
grant execute on function public.finalize_stripe_payment(text, text, text, bigint, text, timestamptz) to service_role;

-- Unified webhook contract for payment_intent.* and checkout.session.completed.
create or replace function public.process_stripe_webhook_event(
  p_event_id text,
  p_event_type text,
  p_payment_intent_id text,
  p_checkout_session_id text,
  p_status text,
  p_amount_received bigint,
  p_currency text,
  p_event_created timestamptz
)
returns table (
  processed boolean,
  payment_id uuid,
  reservation_id uuid,
  payment_status public.payment_status,
  reservation_status public.reservation_status,
  reason text
)
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_payment_id uuid;
  v_result record;
begin
  if not public.is_service_role() then
    raise exception using errcode = '42501', message = 'SERVICE_ROLE_REQUIRED';
  end if;
  if p_event_type not in (
    'payment_intent.succeeded',
    'payment_intent.payment_failed',
    'payment_intent.canceled',
    'checkout.session.completed',
    'checkout.session.async_payment_succeeded',
    'checkout.session.async_payment_failed'
  ) then
    raise exception using errcode = '22023', message = 'UNSUPPORTED_STRIPE_EVENT_TYPE';
  end if;
  if p_payment_intent_id is null or p_payment_intent_id !~ '^pi_[A-Za-z0-9]+$' then
    raise exception using errcode = '22023', message = 'VALID_PAYMENT_INTENT_REQUIRED';
  end if;

  select p.id into v_payment_id
  from public.payments p
  where p.stripe_payment_intent_id = p_payment_intent_id
     or (p_checkout_session_id is not null and p.stripe_checkout_session_id = p_checkout_session_id)
  order by (p.stripe_payment_intent_id = p_payment_intent_id) desc
  limit 1 for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'CHECKOUT_PAYMENT_NOT_FOUND';
  end if;
  update public.payments
    set stripe_payment_intent_id = coalesce(stripe_payment_intent_id, p_payment_intent_id)
  where id = v_payment_id
    and (stripe_payment_intent_id is null or stripe_payment_intent_id = p_payment_intent_id);
  if not found then
    raise exception using errcode = '23505', message = 'PAYMENT_INTENT_BINDING_MISMATCH';
  end if;

  select * into v_result from public.finalize_stripe_payment(
    p_event_id, p_payment_intent_id, p_status, p_amount_received,
    p_currency, p_event_created
  );
  update public.stripe_webhook_events set event_type = p_event_type
    where event_id = p_event_id;
  return query select v_result.processed, v_result.payment_id,
    v_result.reservation_id, v_result.payment_status,
    v_result.reservation_status, v_result.reason;
end;
$$;

revoke all on function public.process_stripe_webhook_event(text, text, text, text, text, bigint, text, timestamptz) from public;
grant execute on function public.process_stripe_webhook_event(text, text, text, text, text, bigint, text, timestamptz) to service_role;

-- Authenticated fallback endpoint verifies Stripe first, then calls this service-only
-- function to atomically apply the already-verified result.
create or replace function public.finalize_verified_stripe_payment(
  p_user_id uuid,
  p_payment_intent_id text,
  p_payment_id uuid,
  p_reservation_id uuid,
  p_amount_cents bigint,
  p_currency text
)
returns text
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_payment public.payments%rowtype;
  v_reservation public.reservations%rowtype;
  v_expected bigint;
begin
  if not public.is_service_role() then
    raise exception using errcode = '42501', message = 'SERVICE_ROLE_REQUIRED';
  end if;
  perform set_config('parkd.trusted_write', 'on', true);
  select * into v_payment from public.payments
    where id = p_payment_id and reservation_id = p_reservation_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'PAYMENT_NOT_FOUND';
  end if;
  select * into v_reservation from public.reservations
    where id = p_reservation_id and driver_id = p_user_id for update;
  if not found then
    raise exception using errcode = '42501', message = 'RESERVATION_NOT_OWNED';
  end if;
  v_expected := round((v_payment.amount + v_payment.service_fee) * 100)::bigint;
  if p_amount_cents <> v_expected or lower(trim(p_currency)) <> v_payment.currency then
    raise exception using errcode = '22023', message = 'VERIFIED_PAYMENT_AMOUNT_MISMATCH';
  end if;
  if v_payment.stripe_payment_intent_id is not null
    and v_payment.stripe_payment_intent_id <> p_payment_intent_id then
    raise exception using errcode = '23505', message = 'PAYMENT_INTENT_BINDING_MISMATCH';
  end if;
  if v_payment.status = 'succeeded'
    and v_reservation.status in ('confirmed', 'active', 'completed') then
    return 'already_processed';
  end if;
  if v_payment.status <> 'pending' or v_reservation.status <> 'pending'
    or v_reservation.checkout_expires_at <= now() then
    raise exception using errcode = '55000', message = 'CHECKOUT_NOT_PENDING';
  end if;
  update public.payments set status = 'succeeded',
    stripe_payment_intent_id = p_payment_intent_id where id = p_payment_id;
  update public.reservations set status = 'confirmed', checkout_expires_at = null
    where id = p_reservation_id;
  insert into public.conversations (reservation_id, host_id, driver_id)
    values (v_reservation.id, v_reservation.host_id, v_reservation.driver_id)
    on conflict on constraint conversations_reservation_id_key do nothing;
  return 'processed';
end;
$$;

revoke all on function public.finalize_verified_stripe_payment(uuid, text, uuid, uuid, bigint, text) from public;
grant execute on function public.finalize_verified_stripe_payment(uuid, text, uuid, uuid, bigint, text) to service_role;

-- Narrow authenticated cancellation path; clients never update the linked payment.
create or replace function public.cancel_checkout_hold(
  p_reservation_id uuid,
  p_reason text default 'driver_cancelled_checkout'
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;
  perform set_config('parkd.trusted_write', 'on', true);
  update public.reservations set status = 'cancelled', cancelled_at = now(),
    cancellation_reason = left(coalesce(nullif(trim(p_reason), ''), 'driver_cancelled_checkout'), 240)
  where id = p_reservation_id and driver_id = auth.uid() and status = 'pending';
  if not found then return false; end if;
  update public.payments set status = 'failed'
    where reservation_id = p_reservation_id and status = 'pending';
  return true;
end;
$$;
revoke all on function public.cancel_checkout_hold(uuid, text) from public;
grant execute on function public.cancel_checkout_hold(uuid, text) to authenticated;

drop policy if exists "reservations_update_participants" on public.reservations;
revoke update on public.reservations from anon, authenticated;

-- Idempotent lifecycle worker. Schedule it externally (Supabase Cron/CI) once per minute.
create or replace function public.advance_reservation_lifecycle(p_now timestamptz default now())
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_expired integer;
  v_active integer;
  v_completed integer;
begin
  if not public.is_service_role() then
    raise exception using errcode = '42501', message = 'SERVICE_ROLE_REQUIRED';
  end if;
  with changed as (
    update public.reservations set status = 'cancelled', cancelled_at = p_now,
      cancellation_reason = 'checkout_expired'
    where status = 'pending' and checkout_expires_at <= p_now returning id
  ) select count(*) into v_expired from changed;
  update public.payments p set status = 'failed'
  where p.status = 'pending' and exists (
    select 1 from public.reservations r where r.id = p.reservation_id
      and r.status = 'cancelled' and r.cancellation_reason = 'checkout_expired'
  );
  with changed as (
    update public.reservations set status = 'active'
    where status = 'confirmed' and start_time <= p_now and end_time > p_now returning id
  ) select count(*) into v_active from changed;
  with changed as (
    update public.reservations set status = 'completed', completed_at = p_now
    where status in ('confirmed', 'active') and end_time <= p_now returning id
  ) select count(*) into v_completed from changed;
  return jsonb_build_object('expired_checkouts', v_expired, 'activated', v_active, 'completed', v_completed);
end;
$$;

revoke all on function public.advance_reservation_lifecycle(timestamptz) from public;
grant execute on function public.advance_reservation_lifecycle(timestamptz) to service_role;

-- Never expose exact address/coordinates from the public listings relation.
drop policy if exists "listings_public_read_published" on public.listings;
create policy "listings_read_owner_or_confirmed_participant"
on public.listings for select
using (
  deleted_at is null and (
    auth.uid() = host_id
    or exists (
      select 1 from public.reservations r
      where r.listing_id = listings.id and r.driver_id = auth.uid()
        and r.status in ('confirmed', 'active', 'completed')
    )
  )
);

drop view if exists public.public_listing_cards;
create view public.public_listing_cards
with (security_barrier = true)
as
select
  l.id,
  l.host_id,
  l.city,
  l.country,
  case when l.postal_code is null then null else split_part(l.postal_code, ' ', 1) end as postal_area,
  round(l.latitude::numeric, 2)::double precision as approximate_latitude,
  round(l.longitude::numeric, 2)::double precision as approximate_longitude,
  l.availability_mode,
  l.created_at,
  l.updated_at
from public.listings l
where l.is_active and l.is_published and l.deleted_at is null;

-- The moderation migration replaces this view to filter blocked relationships.
grant select on public.public_listing_cards to anon, authenticated;
