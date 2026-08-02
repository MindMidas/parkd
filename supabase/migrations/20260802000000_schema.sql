-- Parkd database schema

-- parkd supabase schema


-- extensions
create extension if not exists pgcrypto;
create extension if not exists btree_gist;

-- helpers


create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.request_jwt_role()
returns text
language sql
stable
as $$
  select coalesce(nullif(current_setting('request.jwt.claim.role', true), ''), current_user);
$$;

-- enums


do $$
begin
  create type public.reservation_status as enum (
    'pending',
    'confirmed',
    'active',
    'completed',
    'cancelled'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.payment_status as enum (
    'pending',
    'succeeded',
    'failed',
    'refunded'
  );
exception
  when duplicate_object then null;
end $$;


do $$
begin
  create type public.availability_mode as enum (
    'weekly',
    'specific'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.message_status as enum (
    'sent',
    'read'
  );
exception
  when duplicate_object then null;
end $$;

-- profiles (1:1 auth.users; password policy is auth + dashboard + app)


create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique,
  full_name text,
  email text,
  phone text,
  avatar_url text,
  birth_date date,
  rating numeric(3,2) not null default 0,
  rating_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint profiles_rating_check
    check (rating >= 0 and rating <= 5)
);

-- stripe_customer_id set by edge functions only
alter table public.profiles add column if not exists stripe_customer_id text;
drop index if exists profiles_stripe_customer_id_unique;
create unique index profiles_stripe_customer_id_unique
  on public.profiles (stripe_customer_id)
  where stripe_customer_id is not null and trim(stripe_customer_id) <> '';

-- username / name / phone rules aligned with app validators
alter table public.profiles drop constraint if exists profiles_username_format_check;
alter table public.profiles add constraint profiles_username_format_check
  check (username is null or username ~ '^[a-z0-9_]{3,20}$');

alter table public.profiles drop constraint if exists profiles_full_name_len_check;
alter table public.profiles add constraint profiles_full_name_len_check
  check (full_name is null or char_length(trim(full_name)) >= 2);

-- phone E.164 + and 7–15 digits
alter table public.profiles drop constraint if exists profiles_phone_e164_check;
alter table public.profiles add constraint profiles_phone_e164_check
  check (phone is null or trim(phone) ~ '^\+[1-9][0-9]{6,14}$');

-- unique phone when set
drop index if exists profiles_phone_unique;
create unique index profiles_phone_unique
  on public.profiles (phone)
  where phone is not null and trim(phone) <> '';

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();

create or replace view public.public_profiles as
select
  id,
  username,
  full_name,
  avatar_url,
  rating,
  rating_count,
  created_at
from public.profiles;

grant select on public.public_profiles to anon, authenticated;

create or replace function public.is_username_available(candidate text)
returns boolean
language sql
security definer
set search_path = public
as $$
  select not exists (
    select 1
    from public.profiles p
    where p.username = lower(trim(candidate))
  );
$$;

create or replace function public.is_phone_available(candidate text)
returns boolean
language sql
security definer
set search_path = public
as $$
  select not exists (
    select 1
    from public.profiles p
    where p.phone = trim(candidate)
  );
$$;

grant execute on function public.is_username_available(text) to anon, authenticated;
grant execute on function public.is_phone_available(text) to anon, authenticated;

-- profile after email confirmed (auth.users)

-- No public.profiles row until email_confirmed_at is set. Optional phone on the
-- auth user (or in metadata) is copied when present; sign-up no longer requires phone.

create or replace function public.ensure_profile_after_full_verification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  phone_val text;
begin
  if new.email_confirmed_at is null then
    return new;
  end if;

  phone_val := nullif(trim(coalesce(new.phone, '')), '');
  if phone_val is null or phone_val = '' then
    phone_val := nullif(trim(new.raw_user_meta_data ->> 'phone'), '');
  end if;

  insert into public.profiles (
    id,
    email,
    full_name,
    username,
    phone,
    birth_date
  )
  values (
    new.id,
    new.email,
    nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
    nullif(lower(trim(new.raw_user_meta_data ->> 'username')), ''),
    phone_val,
    case
      when (new.raw_user_meta_data ? 'birth_date')
        and (new.raw_user_meta_data ->> 'birth_date') ~ '^\d{4}-\d{2}-\d{2}$'
      then (new.raw_user_meta_data ->> 'birth_date')::date
      else null
    end
  )
  on conflict (id) do update set
    email = excluded.email,
    full_name = excluded.full_name,
    username = excluded.username,
    phone = excluded.phone,
    birth_date = excluded.birth_date,
    updated_at = now();

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
drop trigger if exists on_auth_user_full_verification on auth.users;
drop function if exists public.handle_new_user();

create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.ensure_profile_after_full_verification();

create trigger on_auth_user_full_verification
after update on auth.users
for each row
execute function public.ensure_profile_after_full_verification();

-- sync profile email when auth.users.email changes
create or replace function public.handle_auth_user_updated()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
  set email = new.email,
      updated_at = now()
  where id = new.id;

  return new;
end;
$$;

drop trigger if exists on_auth_user_updated on auth.users;
create trigger on_auth_user_updated
after update of email on auth.users
for each row
execute function public.handle_auth_user_updated();

-- listings


create table if not exists public.listings (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references public.profiles(id) on delete cascade,

  address text not null,
  city text not null,
  postal_code text,
  country text not null default 'Canada',
  spot_number text,

  latitude double precision not null,
  longitude double precision not null,

  availability_mode public.availability_mode not null default 'weekly',

  is_active boolean not null default false,
  is_published boolean not null default false,

  terms_accepted boolean not null default false,
  terms_accepted_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);


alter table public.listings
  add column if not exists availability_mode public.availability_mode not null default 'weekly';

drop trigger if exists trg_listings_updated_at on public.listings;
create trigger trg_listings_updated_at
before update on public.listings
for each row
execute function public.set_updated_at();

create index if not exists listings_host_id_idx on public.listings(host_id);
create index if not exists listings_active_published_idx on public.listings(is_active, is_published);
create index if not exists listings_city_idx on public.listings(city);

-- unique address when no spot_number; with spot, address+spot unique
drop index if exists listings_unique_address_when_no_spot;
create unique index listings_unique_address_when_no_spot
on public.listings (
  lower(trim(address)),
  lower(trim(city)),
  lower(trim(coalesce(postal_code, ''))),
  lower(trim(country))
)
where spot_number is null or btrim(spot_number) = '';

drop index if exists listings_unique_address_spot_pair;
create unique index listings_unique_address_spot_pair
on public.listings (
  lower(trim(address)),
  lower(trim(city)),
  lower(trim(coalesce(postal_code, ''))),
  lower(trim(country)),
  lower(trim(spot_number))
)
where spot_number is not null and btrim(spot_number) <> '';

-- listing photos


create table if not exists public.listing_photos (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  photo_url text not null,
  sort_order integer not null default 0,
  -- photo marker x/y in 0..1 (annotate step)
  marker_x double precision,
  marker_y double precision,
  created_at timestamptz not null default now()
);

-- idempotent column adds
alter table public.listing_photos add column if not exists marker_x double precision;
alter table public.listing_photos add column if not exists marker_y double precision;

alter table public.listing_photos drop constraint if exists listing_photos_marker_coords_check;
alter table public.listing_photos add constraint listing_photos_marker_coords_check
  check (
    (marker_x is null and marker_y is null)
    or (
      marker_x is not null
      and marker_y is not null
      and marker_x >= 0
      and marker_x <= 1
      and marker_y >= 0
      and marker_y <= 1
    )
  );

create index if not exists listing_photos_listing_id_idx
on public.listing_photos(listing_id);

-- weekly slots (day_of_week 0=sun .. 6=sat)


create table if not exists public.availability_weekly (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  day_of_week integer not null,
  start_time time not null,
  end_time time not null,
  price_hour numeric(10,2) not null default 0,
  price_day numeric(10,2),
  created_at timestamptz not null default now(),

  constraint availability_weekly_day_check
    check (day_of_week between 0 and 6),

  constraint availability_weekly_time_check
    check (end_time > start_time),

  constraint availability_weekly_price_hour_check
    check (price_hour >= 0),

  constraint availability_weekly_price_day_check
    check (price_day is null or price_day >= 0)
);

create index if not exists availability_weekly_listing_id_idx
on public.availability_weekly(listing_id);

-- specific date availability


create table if not exists public.availability_specific (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  start_datetime timestamptz not null,
  end_datetime timestamptz not null,
  price_hour numeric(10,2) not null default 0,
  price_day numeric(10,2),
  created_at timestamptz not null default now(),

  constraint availability_specific_time_check
    check (end_datetime > start_datetime),

  constraint availability_specific_price_hour_check
    check (price_hour >= 0),

  constraint availability_specific_price_day_check
    check (price_day is null or price_day >= 0)
);

create index if not exists availability_specific_listing_id_idx
on public.availability_specific(listing_id);

-- prices on availability rows only; backfill from listings.price_* if those columns exist


alter table public.availability_weekly add column if not exists price_hour numeric(10,2);
alter table public.availability_weekly add column if not exists price_day numeric(10,2);
alter table public.availability_specific add column if not exists price_hour numeric(10,2);
alter table public.availability_specific add column if not exists price_day numeric(10,2);

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'listings' and column_name = 'price_hour'
  ) then
    update public.availability_weekly w
    set
      price_hour = coalesce(w.price_hour, l.price_hour, 0),
      price_day = coalesce(w.price_day, l.price_day)
    from public.listings l
    where w.listing_id = l.id;

    update public.availability_specific s
    set
      price_hour = coalesce(s.price_hour, l.price_hour, 0),
      price_day = coalesce(s.price_day, l.price_day)
    from public.listings l
    where s.listing_id = l.id;
  end if;
end $$;

update public.availability_weekly set price_hour = 0 where price_hour is null;
update public.availability_specific set price_hour = 0 where price_hour is null;

alter table public.availability_weekly alter column price_hour set default 0;
alter table public.availability_specific alter column price_hour set default 0;

alter table public.availability_weekly drop constraint if exists availability_weekly_price_hour_check;
alter table public.availability_weekly add constraint availability_weekly_price_hour_check
  check (price_hour >= 0);

alter table public.availability_specific drop constraint if exists availability_specific_price_hour_check;
alter table public.availability_specific add constraint availability_specific_price_hour_check
  check (price_hour >= 0);

alter table public.availability_weekly alter column price_hour set not null;
alter table public.availability_specific alter column price_hour set not null;

alter table public.listings drop column if exists price_hour;
alter table public.listings drop column if exists price_day;

-- slot rows must match listing.availability_mode (weekly or specific)


create or replace function public.ensure_listing_availability_mode_match()
returns trigger
language plpgsql
as $$
declare
  mode public.availability_mode;
begin
  select l.availability_mode
  into mode
  from public.listings l
  where l.id = new.listing_id;

  if mode is null then
    raise exception 'Listing not found for availability row';
  end if;

  if tg_table_name = 'availability_weekly' and mode <> 'weekly' then
    raise exception 'Listing availability_mode is %, cannot insert weekly slots', mode;
  end if;

  if tg_table_name = 'availability_specific' and mode <> 'specific' then
    raise exception 'Listing availability_mode is %, cannot insert specific slots', mode;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_availability_weekly_mode_guard on public.availability_weekly;
create trigger trg_availability_weekly_mode_guard
before insert or update on public.availability_weekly
for each row
execute function public.ensure_listing_availability_mode_match();

drop trigger if exists trg_availability_specific_mode_guard on public.availability_specific;
create trigger trg_availability_specific_mode_guard
before insert or update on public.availability_specific
for each row
execute function public.ensure_listing_availability_mode_match();

-- no overlapping slots per listing ([start,end) half-open; raises OVERLAP_AVAILABILITY_* )


create or replace function public.prevent_overlapping_availability_weekly()
returns trigger
language plpgsql
as $fn$
begin
  if exists (
    select 1
    from public.availability_weekly o
    where o.listing_id = new.listing_id
      and o.day_of_week = new.day_of_week
      and o.id is distinct from new.id
      and o.start_time < new.end_time
      and o.end_time > new.start_time
  ) then
    raise exception 'OVERLAP_AVAILABILITY_WEEKLY';
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_availability_weekly_overlap_guard on public.availability_weekly;
create trigger trg_availability_weekly_overlap_guard
before insert or update on public.availability_weekly
for each row
execute function public.prevent_overlapping_availability_weekly();

create or replace function public.prevent_overlapping_availability_specific()
returns trigger
language plpgsql
as $fn$
begin
  if exists (
    select 1
    from public.availability_specific o
    where o.listing_id = new.listing_id
      and o.id is distinct from new.id
      and o.start_datetime < new.end_datetime
      and o.end_datetime > new.start_datetime
  ) then
    raise exception 'OVERLAP_AVAILABILITY_SPECIFIC';
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_availability_specific_overlap_guard on public.availability_specific;
create trigger trg_availability_specific_overlap_guard
before insert or update on public.availability_specific
for each row
execute function public.prevent_overlapping_availability_specific();

create or replace function public.prevent_availability_mode_switch_with_existing_rows()
returns trigger
language plpgsql
as $$
declare
  has_weekly boolean;
  has_specific boolean;
begin
  if new.availability_mode = old.availability_mode then
    return new;
  end if;

  select exists (
    select 1 from public.availability_weekly w where w.listing_id = new.id
  ) into has_weekly;

  select exists (
    select 1 from public.availability_specific s where s.listing_id = new.id
  ) into has_specific;

  if new.availability_mode = 'weekly' and has_specific then
    raise exception 'Cannot switch listing to weekly while specific slots exist';
  end if;

  if new.availability_mode = 'specific' and has_weekly then
    raise exception 'Cannot switch listing to specific while weekly slots exist';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_listings_availability_mode_guard on public.listings;
create trigger trg_listings_availability_mode_guard
before update of availability_mode on public.listings
for each row
execute function public.prevent_availability_mode_switch_with_existing_rows();


-- payment_methods: stripe ids + display fields only


create table if not exists public.payment_methods (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  stripe_payment_method_id text unique,
  brand text,
  last4 text,
  exp_month integer,
  exp_year integer,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint payment_methods_exp_month_check
    check (exp_month is null or exp_month between 1 and 12)
);

drop trigger if exists trg_payment_methods_updated_at on public.payment_methods;
create trigger trg_payment_methods_updated_at
before update on public.payment_methods
for each row
execute function public.set_updated_at();

create index if not exists payment_methods_user_id_idx
on public.payment_methods(user_id);

create or replace function public.prevent_untrusted_payment_method_changes()
returns trigger
language plpgsql
as $$
begin
  if public.request_jwt_role() not in ('anon', 'authenticated') then
    return new;
  end if;

  if tg_op = 'INSERT' then
    raise exception 'PAYMENT_METHODS_EDGE_ONLY';
  end if;

  if new.user_id is distinct from old.user_id
    or new.stripe_payment_method_id is distinct from old.stripe_payment_method_id
    or new.brand is distinct from old.brand
    or new.last4 is distinct from old.last4
    or new.exp_month is distinct from old.exp_month
    or new.exp_year is distinct from old.exp_year
  then
    raise exception 'PAYMENT_METHOD_TRUSTED_FIELDS_SERVER_ONLY';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_payment_methods_untrusted_change_guard on public.payment_methods;
create trigger trg_payment_methods_untrusted_change_guard
before insert or update on public.payment_methods
for each row
execute function public.prevent_untrusted_payment_method_changes();

-- reservations


create table if not exists public.reservations (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  driver_id uuid not null references public.profiles(id) on delete cascade,
  host_id uuid not null references public.profiles(id) on delete cascade,

  start_time timestamptz not null,
  end_time timestamptz not null,

  total_price numeric(10,2) not null default 0,
  service_fee numeric(10,2) not null default 0,
  amount_paid numeric(10,2) generated always as (total_price + service_fee) stored,

  status public.reservation_status not null default 'pending',

  extended_from_reservation_id uuid references public.reservations(id) on delete set null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint reservations_time_check
    check (end_time > start_time),

  constraint reservations_price_check
    check (total_price >= 0 and service_fee >= 0),

  -- driver must not be listing host (host_id comes from listing)
  constraint reservations_driver_host_check
    check (driver_id <> host_id)
);

drop trigger if exists trg_reservations_updated_at on public.reservations;
create trigger trg_reservations_updated_at
before update on public.reservations
for each row
execute function public.set_updated_at();

create index if not exists reservations_listing_id_idx on public.reservations(listing_id);
create index if not exists reservations_driver_id_idx on public.reservations(driver_id);
create index if not exists reservations_host_id_idx on public.reservations(host_id);
create index if not exists reservations_status_idx on public.reservations(status);
create index if not exists reservations_start_end_idx on public.reservations(start_time, end_time);

-- set host_id from listing
create or replace function public.set_reservation_host_id()
returns trigger
language plpgsql
as $$
begin
  select l.host_id
  into new.host_id
  from public.listings l
  where l.id = new.listing_id;

  if new.host_id is null then
    raise exception 'Listing host not found for reservation';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_set_reservation_host_id on public.reservations;
create trigger trg_set_reservation_host_id
before insert on public.reservations
for each row
execute function public.set_reservation_host_id();

-- friendly error if driver == host after host_id set
create or replace function public.assert_reservation_not_own_listing()
returns trigger
language plpgsql
as $$
begin
  if new.driver_id is not distinct from new.host_id then
    raise exception 'Cannot reserve your own listing';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_validate_reservation_not_own_listing on public.reservations;
create trigger trg_validate_reservation_not_own_listing
before insert or update of driver_id, listing_id, host_id on public.reservations
for each row
execute function public.assert_reservation_not_own_listing();

-- A listing cannot have overlapping live reservations. Pending reservations may
-- overlap while users are in checkout, but only one can be confirmed/active.
create or replace function public.prevent_overlapping_live_reservations()
returns trigger
language plpgsql
as $$
begin
  if new.status not in ('confirmed', 'active') then
    return new;
  end if;

  if exists (
    select 1
    from public.reservations o
    where o.listing_id = new.listing_id
      and o.id is distinct from new.id
      and o.status in ('confirmed', 'active')
      and o.start_time < new.end_time
      and o.end_time > new.start_time
  ) then
    raise exception 'OVERLAP_RESERVATION';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_reservations_live_overlap_guard on public.reservations;
create trigger trg_reservations_live_overlap_guard
before insert or update of listing_id, start_time, end_time, status on public.reservations
for each row
execute function public.prevent_overlapping_live_reservations();

alter table public.reservations
  drop constraint if exists reservations_no_live_overlap;

alter table public.reservations
  add constraint reservations_no_live_overlap
  exclude using gist (
    listing_id with =,
    tstzrange(start_time, end_time, '[)') with &&
  )
  where (status in ('confirmed', 'active'));

create or replace function public.prevent_untrusted_reservation_updates()
returns trigger
language plpgsql
as $$
begin
  if public.request_jwt_role() not in ('anon', 'authenticated') then
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.status := 'pending';
    return new;
  end if;

  if new.listing_id is distinct from old.listing_id
    or new.driver_id is distinct from old.driver_id
    or new.host_id is distinct from old.host_id
    or new.start_time is distinct from old.start_time
    or new.end_time is distinct from old.end_time
    or new.total_price is distinct from old.total_price
    or new.service_fee is distinct from old.service_fee
    or new.extended_from_reservation_id is distinct from old.extended_from_reservation_id
  then
    raise exception 'RESERVATION_IMMUTABLE_FIELDS';
  end if;

  if new.status is distinct from old.status
    and not (
      new.status = 'cancelled'
      and old.status in ('pending', 'confirmed', 'active')
    )
  then
    raise exception 'RESERVATION_STATUS_SERVER_ONLY';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_reservations_untrusted_update_guard on public.reservations;
create trigger trg_reservations_untrusted_update_guard
before insert or update on public.reservations
for each row
execute function public.prevent_untrusted_reservation_updates();

-- payments: one row per reservation


create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  reservation_id uuid not null unique references public.reservations(id) on delete cascade,
  payment_method_id uuid references public.payment_methods(id) on delete set null,
  stripe_payment_intent_id text unique,
  amount numeric(10,2) not null default 0,
  service_fee numeric(10,2) not null default 0,
  status public.payment_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint payments_amount_check
    check (amount >= 0 and service_fee >= 0)
);

drop trigger if exists trg_payments_updated_at on public.payments;
create trigger trg_payments_updated_at
before update on public.payments
for each row
execute function public.set_updated_at();

create index if not exists payments_reservation_id_idx
on public.payments(reservation_id);

create or replace function public.prevent_untrusted_payment_changes()
returns trigger
language plpgsql
as $$
declare
  reservation_amount numeric(10,2);
  reservation_fee numeric(10,2);
begin
  if public.request_jwt_role() not in ('anon', 'authenticated') then
    return new;
  end if;

  if tg_op = 'INSERT' then
    select r.total_price, r.service_fee
    into reservation_amount, reservation_fee
    from public.reservations r
    where r.id = new.reservation_id;

    if reservation_amount is null then
      raise exception 'PAYMENT_RESERVATION_NOT_FOUND';
    end if;

    new.amount := reservation_amount;
    new.service_fee := reservation_fee;
    new.status := 'pending';
    new.stripe_payment_intent_id := null;
    return new;
  end if;

  if new.reservation_id is distinct from old.reservation_id
    or new.payment_method_id is distinct from old.payment_method_id
    or new.stripe_payment_intent_id is distinct from old.stripe_payment_intent_id
    or new.amount is distinct from old.amount
    or new.service_fee is distinct from old.service_fee
  then
    raise exception 'PAYMENT_TRUSTED_FIELDS_SERVER_ONLY';
  end if;

  if new.status is distinct from old.status
    and not (
      old.status = 'pending'
      and new.status = 'failed'
    )
  then
    raise exception 'PAYMENT_STATUS_SERVER_ONLY';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_payments_untrusted_change_guard on public.payments;
create trigger trg_payments_untrusted_change_guard
before insert or update on public.payments
for each row
execute function public.prevent_untrusted_payment_changes();

-- conversations: one per reservation


create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  reservation_id uuid not null unique references public.reservations(id) on delete cascade,
  host_id uuid not null references public.profiles(id) on delete cascade,
  driver_id uuid not null references public.profiles(id) on delete cascade,
  is_closed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint conversations_driver_host_check
    check (driver_id <> host_id)
);

drop trigger if exists trg_conversations_updated_at on public.conversations;
create trigger trg_conversations_updated_at
before update on public.conversations
for each row
execute function public.set_updated_at();

create index if not exists conversations_host_id_idx on public.conversations(host_id);
create index if not exists conversations_driver_id_idx on public.conversations(driver_id);

-- set participants from reservation
create or replace function public.set_conversation_participants()
returns trigger
language plpgsql
as $$
begin
  select r.host_id, r.driver_id
  into new.host_id, new.driver_id
  from public.reservations r
  where r.id = new.reservation_id;

  if new.host_id is null or new.driver_id is null then
    raise exception 'Reservation participants not found for conversation';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_set_conversation_participants on public.conversations;
create trigger trg_set_conversation_participants
before insert on public.conversations
for each row
execute function public.set_conversation_participants();

-- messages


create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  message text not null,
  status public.message_status not null default 'sent',
  created_at timestamptz not null default now()
);

create index if not exists messages_conversation_id_idx
on public.messages(conversation_id);

create index if not exists messages_sender_id_idx
on public.messages(sender_id);

create or replace function public.prevent_untrusted_message_updates()
returns trigger
language plpgsql
as $$
begin
  if public.request_jwt_role() not in ('anon', 'authenticated') then
    return new;
  end if;

  if new.conversation_id is distinct from old.conversation_id
    or new.sender_id is distinct from old.sender_id
    or new.message is distinct from old.message
    or new.created_at is distinct from old.created_at
  then
    raise exception 'MESSAGE_CONTENT_IMMUTABLE';
  end if;

  if new.status is distinct from old.status
    and not (
      old.status = 'sent'
      and new.status = 'read'
    )
  then
    raise exception 'MESSAGE_STATUS_INVALID';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_messages_untrusted_update_guard on public.messages;
create trigger trg_messages_untrusted_update_guard
before update on public.messages
for each row
execute function public.prevent_untrusted_message_updates();

-- reviews


create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  reservation_id uuid not null unique references public.reservations(id) on delete cascade,
  reviewer_id uuid not null references public.profiles(id) on delete cascade,
  reviewee_id uuid not null references public.profiles(id) on delete cascade,
  rating integer not null,
  comment text,
  created_at timestamptz not null default now(),

  constraint reviews_rating_check
    check (rating between 1 and 5),

  constraint reviews_self_check
    check (reviewer_id <> reviewee_id)
);

create index if not exists reviews_reviewee_id_idx
on public.reviews(reviewee_id);

-- host earnings view


create or replace view public.host_earnings as
select
  r.host_id,
  date_trunc('month', r.start_time) as month,
  count(*) filter (
    where r.status in ('confirmed', 'active', 'completed')
  ) as reservation_count,
  coalesce(
    sum(r.total_price) filter (
      where r.status in ('confirmed', 'active', 'completed')
    ),
    0
  ) as gross_earnings
from public.reservations r
group by r.host_id, date_trunc('month', r.start_time);

-- rls


alter table public.profiles enable row level security;
alter table public.listings enable row level security;
alter table public.listing_photos enable row level security;
alter table public.availability_weekly enable row level security;
alter table public.availability_specific enable row level security;
alter table public.payment_methods enable row level security;
alter table public.reservations enable row level security;
alter table public.payments enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.reviews enable row level security;

-- profiles policies


drop policy if exists "profiles_public_read" on public.profiles;
drop policy if exists "profiles_read_own_or_reservation_participant" on public.profiles;
create policy "profiles_read_own_or_reservation_participant"
on public.profiles
for select
using (
  auth.uid() = id
  or exists (
    select 1
    from public.reservations r
    where (
      r.driver_id = auth.uid()
      and r.host_id = profiles.id
    )
    or (
      r.host_id = auth.uid()
      and r.driver_id = profiles.id
    )
  )
);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
on public.profiles
for insert
with check (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
on public.profiles
for update
using (auth.uid() = id);

-- listings policies


drop policy if exists "listings_public_read_published" on public.listings;
create policy "listings_public_read_published"
on public.listings
for select
using (
  (is_published = true and is_active = true)
  or auth.uid() = host_id
);

drop policy if exists "listings_host_insert" on public.listings;
create policy "listings_host_insert"
on public.listings
for insert
with check (auth.uid() = host_id);

drop policy if exists "listings_host_update" on public.listings;
create policy "listings_host_update"
on public.listings
for update
using (auth.uid() = host_id);

drop policy if exists "listings_host_delete" on public.listings;
create policy "listings_host_delete"
on public.listings
for delete
using (auth.uid() = host_id);

-- listing photos policies


drop policy if exists "listing_photos_read" on public.listing_photos;
create policy "listing_photos_read"
on public.listing_photos
for select
using (
  exists (
    select 1
    from public.listings l
    where l.id = listing_id
      and (
        (l.is_published = true and l.is_active = true)
        or l.host_id = auth.uid()
      )
  )
);

drop policy if exists "listing_photos_insert" on public.listing_photos;
create policy "listing_photos_insert"
on public.listing_photos
for insert
with check (
  exists (
    select 1
    from public.listings l
    where l.id = listing_id
      and l.host_id = auth.uid()
  )
);

drop policy if exists "listing_photos_update" on public.listing_photos;
create policy "listing_photos_update"
on public.listing_photos
for update
using (
  exists (
    select 1
    from public.listings l
    where l.id = listing_id
      and l.host_id = auth.uid()
  )
);

drop policy if exists "listing_photos_delete" on public.listing_photos;
create policy "listing_photos_delete"
on public.listing_photos
for delete
using (
  exists (
    select 1
    from public.listings l
    where l.id = listing_id
      and l.host_id = auth.uid()
  )
);

-- weekly availability policies


drop policy if exists "availability_weekly_read" on public.availability_weekly;
create policy "availability_weekly_read"
on public.availability_weekly
for select
using (
  exists (
    select 1
    from public.listings l
    where l.id = listing_id
      and (
        (l.is_published = true and l.is_active = true)
        or l.host_id = auth.uid()
      )
  )
);

drop policy if exists "availability_weekly_insert" on public.availability_weekly;
create policy "availability_weekly_insert"
on public.availability_weekly
for insert
with check (
  exists (
    select 1
    from public.listings l
    where l.id = listing_id
      and l.host_id = auth.uid()
  )
);

drop policy if exists "availability_weekly_update" on public.availability_weekly;
create policy "availability_weekly_update"
on public.availability_weekly
for update
using (
  exists (
    select 1
    from public.listings l
    where l.id = listing_id
      and l.host_id = auth.uid()
  )
);

drop policy if exists "availability_weekly_delete" on public.availability_weekly;
create policy "availability_weekly_delete"
on public.availability_weekly
for delete
using (
  exists (
    select 1
    from public.listings l
    where l.id = listing_id
      and l.host_id = auth.uid()
  )
);

-- specific availability policies


drop policy if exists "availability_specific_read" on public.availability_specific;
create policy "availability_specific_read"
on public.availability_specific
for select
using (
  exists (
    select 1
    from public.listings l
    where l.id = listing_id
      and (
        (l.is_published = true and l.is_active = true)
        or l.host_id = auth.uid()
      )
  )
);

drop policy if exists "availability_specific_insert" on public.availability_specific;
create policy "availability_specific_insert"
on public.availability_specific
for insert
with check (
  exists (
    select 1
    from public.listings l
    where l.id = listing_id
      and l.host_id = auth.uid()
  )
);

drop policy if exists "availability_specific_update" on public.availability_specific;
create policy "availability_specific_update"
on public.availability_specific
for update
using (
  exists (
    select 1
    from public.listings l
    where l.id = listing_id
      and l.host_id = auth.uid()
  )
);

drop policy if exists "availability_specific_delete" on public.availability_specific;
create policy "availability_specific_delete"
on public.availability_specific
for delete
using (
  exists (
    select 1
    from public.listings l
    where l.id = listing_id
      and l.host_id = auth.uid()
  )
);

-- payment methods policies


drop policy if exists "payment_methods_read_own" on public.payment_methods;
create policy "payment_methods_read_own"
on public.payment_methods
for select
using (auth.uid() = user_id);

drop policy if exists "payment_methods_insert_own" on public.payment_methods;
create policy "payment_methods_insert_own"
on public.payment_methods
for insert
with check (auth.uid() = user_id);

drop policy if exists "payment_methods_update_own" on public.payment_methods;
create policy "payment_methods_update_own"
on public.payment_methods
for update
using (auth.uid() = user_id);

drop policy if exists "payment_methods_delete_own" on public.payment_methods;
create policy "payment_methods_delete_own"
on public.payment_methods
for delete
using (auth.uid() = user_id);

-- reservations policies


drop policy if exists "reservations_read_participants" on public.reservations;
create policy "reservations_read_participants"
on public.reservations
for select
using (auth.uid() = driver_id or auth.uid() = host_id);

drop policy if exists "reservations_driver_insert" on public.reservations;
create policy "reservations_driver_insert"
on public.reservations
for insert
with check (auth.uid() = driver_id);

drop policy if exists "reservations_update_participants" on public.reservations;
create policy "reservations_update_participants"
on public.reservations
for update
using (auth.uid() = driver_id or auth.uid() = host_id);

-- payments policies


drop policy if exists "payments_read_participants" on public.payments;
create policy "payments_read_participants"
on public.payments
for select
using (
  exists (
    select 1
    from public.reservations r
    where r.id = reservation_id
      and (r.driver_id = auth.uid() or r.host_id = auth.uid())
  )
);

drop policy if exists "payments_driver_insert" on public.payments;
create policy "payments_driver_insert"
on public.payments
for insert
with check (
  exists (
    select 1
    from public.reservations r
    where r.id = reservation_id
      and r.driver_id = auth.uid()
  )
);

drop policy if exists "payments_update_participants" on public.payments;
create policy "payments_update_participants"
on public.payments
for update
using (
  exists (
    select 1
    from public.reservations r
    where r.id = reservation_id
      and (r.driver_id = auth.uid() or r.host_id = auth.uid())
  )
);

-- conversations policies


drop policy if exists "conversations_read_participants" on public.conversations;
create policy "conversations_read_participants"
on public.conversations
for select
using (auth.uid() = host_id or auth.uid() = driver_id);

drop policy if exists "conversations_insert_participants" on public.conversations;
create policy "conversations_insert_participants"
on public.conversations
for insert
with check (auth.uid() = host_id or auth.uid() = driver_id);

drop policy if exists "conversations_update_participants" on public.conversations;
create policy "conversations_update_participants"
on public.conversations
for update
using (auth.uid() = host_id or auth.uid() = driver_id);

-- messages policies


drop policy if exists "messages_read_participants" on public.messages;
create policy "messages_read_participants"
on public.messages
for select
using (
  exists (
    select 1
    from public.conversations c
    where c.id = conversation_id
      and (c.host_id = auth.uid() or c.driver_id = auth.uid())
  )
);

drop policy if exists "messages_insert_participants" on public.messages;
create policy "messages_insert_participants"
on public.messages
for insert
with check (
  sender_id = auth.uid()
  and exists (
    select 1
    from public.conversations c
    where c.id = conversation_id
      and c.is_closed = false
      and (c.host_id = auth.uid() or c.driver_id = auth.uid())
  )
);

drop policy if exists "messages_update_participants" on public.messages;
create policy "messages_update_participants"
on public.messages
for update
using (
  exists (
    select 1
    from public.conversations c
    where c.id = conversation_id
      and (c.host_id = auth.uid() or c.driver_id = auth.uid())
  )
);

-- reviews policies


drop policy if exists "reviews_read_all" on public.reviews;
create policy "reviews_read_all"
on public.reviews
for select
using (true);

drop policy if exists "reviews_insert_reviewer" on public.reviews;
create policy "reviews_insert_reviewer"
on public.reviews
for insert
with check (auth.uid() = reviewer_id);

-- if both weekly and specific existed: drop weekly for that listing, set availability_mode from remaining rows


begin;

delete from public.availability_weekly w
where exists (
  select 1
  from public.availability_specific s
  where s.listing_id = w.listing_id
);

update public.listings l
set availability_mode = 'specific'
where exists (
  select 1 from public.availability_specific s where s.listing_id = l.id
);

update public.listings l
set availability_mode = 'weekly'
where exists (
  select 1 from public.availability_weekly w where w.listing_id = l.id
)
and not exists (
  select 1 from public.availability_specific s where s.listing_id = l.id
);

commit;



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

-- Soft deletion preserves the financial audit trail.
alter table public.profiles
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

create index if not exists listings_not_deleted_idx
  on public.listings (is_active, is_published)
  where deleted_at is null;
create index if not exists reservations_checkout_expiry_idx
  on public.reservations (checkout_expires_at)
  where status = 'pending';

-- Only the auth trigger/service role can change identity and trust fields.
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



-- Moderation, content integrity, soft deletion, retention, and storage RLS.

-- Decouple retained/anonymized profile records from auth.users so an Edge Function
-- can delete the Auth identity without cascading the financial audit trail.
alter table public.profiles drop constraint if exists profiles_id_fkey;

alter table public.reservations drop constraint if exists reservations_listing_id_fkey;
alter table public.reservations add constraint reservations_listing_id_fkey
  foreign key (listing_id) references public.listings(id) on delete restrict;
alter table public.reservations drop constraint if exists reservations_driver_id_fkey;
alter table public.reservations add constraint reservations_driver_id_fkey
  foreign key (driver_id) references public.profiles(id) on delete restrict;
alter table public.reservations drop constraint if exists reservations_host_id_fkey;
alter table public.reservations add constraint reservations_host_id_fkey
  foreign key (host_id) references public.profiles(id) on delete restrict;
alter table public.payments drop constraint if exists payments_reservation_id_fkey;
alter table public.payments add constraint payments_reservation_id_fkey
  foreign key (reservation_id) references public.reservations(id) on delete restrict;

create table if not exists public.app_admins (
  user_id uuid primary key references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now()
);
alter table public.app_admins enable row level security;
revoke all on public.app_admins from anon, authenticated;

create or replace function public.is_app_admin(p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select p_user_id is not null and exists (
    select 1 from public.app_admins a where a.user_id = p_user_id
  );
$$;
revoke all on function public.is_app_admin(uuid) from public;
grant execute on function public.is_app_admin(uuid) to authenticated, service_role;

do $$ begin
  create type public.report_target_type as enum ('user', 'listing', 'message', 'review');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.report_reason as enum ('spam', 'harassment', 'fraud', 'inappropriate', 'safety', 'other');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.report_status as enum ('open', 'reviewing', 'resolved', 'dismissed');
exception when duplicate_object then null; end $$;

create table if not exists public.user_blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_user_id),
  constraint user_blocks_not_self check (blocker_id <> blocked_user_id)
);
create index if not exists user_blocks_blocked_idx on public.user_blocks(blocked_user_id);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete restrict,
  target_type public.report_target_type not null,
  target_id uuid not null,
  reported_user_id uuid not null references public.profiles(id) on delete restrict,
  reason public.report_reason not null,
  details text,
  status public.report_status not null default 'open',
  moderator_id uuid references public.profiles(id) on delete restrict,
  moderator_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz,
  constraint reports_details_length check (details is null or char_length(details) <= 2000),
  constraint reports_moderator_notes_length check (moderator_notes is null or char_length(moderator_notes) <= 4000),
  constraint reports_not_self check (reporter_id <> reported_user_id)
);
create index if not exists reports_queue_idx on public.reports(status, created_at);
create index if not exists reports_reporter_idx on public.reports(reporter_id, created_at);
create unique index if not exists reports_one_open_target_per_reporter
  on public.reports(reporter_id, target_type, target_id)
  where status in ('open', 'reviewing');
drop trigger if exists trg_reports_updated_at on public.reports;
create trigger trg_reports_updated_at before update on public.reports
for each row execute function public.set_updated_at();

create or replace function public.validate_report_target()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_reported uuid;
  v_conversation uuid;
begin
  if new.target_type = 'user' then
    select id into v_reported from public.profiles where id = new.target_id and deleted_at is null;
  elsif new.target_type = 'listing' then
    select host_id into v_reported from public.listings where id = new.target_id and deleted_at is null;
  elsif new.target_type = 'message' then
    select m.sender_id, m.conversation_id into v_reported, v_conversation
      from public.messages m where m.id = new.target_id;
    if v_conversation is not null and not exists (
      select 1 from public.conversations c where c.id = v_conversation
        and new.reporter_id in (c.host_id, c.driver_id)
    ) then
      raise exception using errcode = '42501', message = 'REPORTER_CANNOT_ACCESS_MESSAGE';
    end if;
  elsif new.target_type = 'review' then
    select reviewer_id into v_reported from public.reviews where id = new.target_id;
  end if;
  if v_reported is null then
    raise exception using errcode = 'P0002', message = 'REPORT_TARGET_NOT_FOUND';
  end if;
  new.reported_user_id := v_reported;
  if new.reporter_id = v_reported then
    raise exception using errcode = '22023', message = 'CANNOT_REPORT_SELF';
  end if;
  return new;
end;
$$;
drop trigger if exists trg_reports_validate_target on public.reports;
create trigger trg_reports_validate_target before insert or update of target_type, target_id
on public.reports for each row execute function public.validate_report_target();

alter table public.user_blocks enable row level security;
alter table public.reports enable row level security;

create policy "user_blocks_read_own" on public.user_blocks for select
  using (blocker_id = auth.uid());
create policy "user_blocks_insert_own" on public.user_blocks for insert
  with check (blocker_id = auth.uid());
create policy "user_blocks_delete_own" on public.user_blocks for delete
  using (blocker_id = auth.uid());

create policy "reports_insert_own" on public.reports for insert
  with check (reporter_id = auth.uid() and status = 'open' and moderator_id is null);
create policy "reports_read_own_or_admin" on public.reports for select
  using (reporter_id = auth.uid() or public.is_app_admin());
create policy "reports_admin_update" on public.reports for update
  using (public.is_app_admin()) with check (public.is_app_admin());

create or replace function public.guard_report_moderation_fields()
returns trigger
language plpgsql
set search_path = public, pg_catalog
as $$
begin
  if public.is_service_role() then return new; end if;
  if new.id is distinct from old.id or new.reporter_id is distinct from old.reporter_id
    or new.target_type is distinct from old.target_type or new.target_id is distinct from old.target_id
    or new.reported_user_id is distinct from old.reported_user_id
    or new.reason is distinct from old.reason or new.details is distinct from old.details
    or new.created_at is distinct from old.created_at then
    raise exception using errcode = '42501', message = 'REPORT_TARGET_IMMUTABLE';
  end if;
  if not public.is_app_admin() then
    raise exception using errcode = '42501', message = 'ADMIN_REQUIRED';
  end if;
  if new.status is distinct from old.status and not (
    (old.status = 'open' and new.status in ('reviewing','resolved','dismissed'))
    or (old.status = 'reviewing' and new.status in ('resolved','dismissed'))
  ) then
    raise exception using errcode = '22023', message = 'INVALID_REPORT_STATUS_TRANSITION';
  end if;
  new.moderator_id := auth.uid();
  if new.status in ('resolved','dismissed') then new.resolved_at := coalesce(new.resolved_at, now());
  else new.resolved_at := null; end if;
  return new;
end;
$$;
drop trigger if exists trg_reports_moderation_guard on public.reports;
create trigger trg_reports_moderation_guard before update on public.reports
for each row execute function public.guard_report_moderation_fields();

create or replace function public.submit_report(
  p_target_type text,
  p_target_id uuid,
  p_reason text,
  p_details text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_id uuid;
  v_type public.report_target_type;
  v_reason public.report_reason;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;
  if not exists (select 1 from public.profiles where id = auth.uid() and deleted_at is null) then
    raise exception using errcode = '42501', message = 'ACTIVE_PROFILE_REQUIRED';
  end if;
  begin v_type := lower(trim(p_target_type))::public.report_target_type;
  exception when invalid_text_representation then
    raise exception using errcode = '22023', message = 'INVALID_REPORT_TARGET_TYPE'; end;
  begin v_reason := lower(trim(p_reason))::public.report_reason;
  exception when invalid_text_representation then
    raise exception using errcode = '22023', message = 'INVALID_REPORT_REASON'; end;
  insert into public.reports (reporter_id, target_type, target_id, reason, details)
  values (auth.uid(), v_type, p_target_id, v_reason, nullif(trim(p_details), ''))
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.submit_report(text, uuid, text, text) from public;
grant execute on function public.submit_report(text, uuid, text, text) to authenticated;

create or replace function public.set_user_block(p_blocked_user_id uuid, p_blocked boolean)
returns boolean
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if auth.uid() is null or auth.uid() = p_blocked_user_id then
    raise exception using errcode = '22023', message = 'INVALID_BLOCK_TARGET';
  end if;
  if not exists (select 1 from public.profiles where id = p_blocked_user_id and deleted_at is null) then
    raise exception using errcode = 'P0002', message = 'BLOCK_TARGET_NOT_FOUND';
  end if;
  if p_blocked then
    insert into public.user_blocks(blocker_id, blocked_user_id)
      values (auth.uid(), p_blocked_user_id) on conflict do nothing;
  else
    delete from public.user_blocks
      where blocker_id = auth.uid() and blocked_user_id = p_blocked_user_id;
  end if;
  return p_blocked;
end;
$$;
revoke all on function public.set_user_block(uuid, boolean) from public;
grant execute on function public.set_user_block(uuid, boolean) to authenticated;

-- Conversation participants are derived once from the reservation and are immutable.
create or replace function public.guard_conversation_integrity()
returns trigger
language plpgsql
set search_path = public, pg_catalog
as $$
begin
  if public.is_trusted_write() then return new; end if;
  if new.reservation_id is distinct from old.reservation_id
    or new.host_id is distinct from old.host_id
    or new.driver_id is distinct from old.driver_id
    or new.created_at is distinct from old.created_at then
    raise exception using errcode = '42501', message = 'CONVERSATION_PARTICIPANTS_IMMUTABLE';
  end if;
  if old.is_closed and not new.is_closed then
    raise exception using errcode = '42501', message = 'CONVERSATION_CANNOT_REOPEN';
  end if;
  return new;
end;
$$;
drop trigger if exists trg_conversations_integrity on public.conversations;
create trigger trg_conversations_integrity before update on public.conversations
for each row execute function public.guard_conversation_integrity();

alter table public.messages add column if not exists read_at timestamptz;
alter table public.messages drop constraint if exists messages_content_length_check;
alter table public.messages add constraint messages_content_length_check
  check (char_length(trim(message)) between 1 and 2000);

create or replace function public.guard_message_integrity()
returns trigger
language plpgsql
set search_path = public, pg_catalog
as $$
declare
  v_host uuid;
  v_driver uuid;
  v_closed boolean;
begin
  if tg_op = 'INSERT' then
    select host_id, driver_id, is_closed into v_host, v_driver, v_closed
      from public.conversations where id = new.conversation_id;
    if new.sender_id not in (v_host, v_driver) or v_closed then
      raise exception using errcode = '42501', message = 'INVALID_MESSAGE_SENDER_OR_CLOSED_CONVERSATION';
    end if;
    if exists (
      select 1 from public.user_blocks b
      where (b.blocker_id = v_host and b.blocked_user_id = v_driver)
         or (b.blocker_id = v_driver and b.blocked_user_id = v_host)
    ) then
      raise exception using errcode = '42501', message = 'MESSAGING_BLOCKED';
    end if;
    new.message := trim(new.message);
    new.status := 'sent';
    new.read_at := null;
    return new;
  end if;

  if public.is_trusted_write() then return new; end if;
  if new.conversation_id is distinct from old.conversation_id
    or new.sender_id is distinct from old.sender_id
    or new.message is distinct from old.message
    or new.created_at is distinct from old.created_at then
    raise exception using errcode = '42501', message = 'MESSAGE_CONTENT_IMMUTABLE';
  end if;
  if old.status <> 'sent' or new.status <> 'read' or auth.uid() = old.sender_id then
    raise exception using errcode = '42501', message = 'ONLY_RECIPIENT_CAN_MARK_READ';
  end if;
  new.read_at := coalesce(new.read_at, now());
  return new;
end;
$$;
drop trigger if exists trg_messages_untrusted_update_guard on public.messages;
drop trigger if exists trg_messages_integrity on public.messages;
create trigger trg_messages_integrity before insert or update on public.messages
for each row execute function public.guard_message_integrity();

-- Both reservation participants may review each other once after completion.
alter table public.reviews drop constraint if exists reviews_reservation_id_key;
create unique index if not exists reviews_reservation_reviewer_unique
  on public.reviews(reservation_id, reviewer_id);
create or replace function public.validate_review_integrity()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_driver uuid;
  v_host uuid;
  v_status public.reservation_status;
begin
  select driver_id, host_id, status into v_driver, v_host, v_status
    from public.reservations where id = new.reservation_id;
  if v_status <> 'completed' then
    raise exception using errcode = '42501', message = 'COMPLETED_RESERVATION_REQUIRED_FOR_REVIEW';
  end if;
  if not ((new.reviewer_id = v_driver and new.reviewee_id = v_host)
       or (new.reviewer_id = v_host and new.reviewee_id = v_driver)) then
    raise exception using errcode = '42501', message = 'INVALID_REVIEW_PARTICIPANTS';
  end if;
  return new;
end;
$$;
drop trigger if exists trg_reviews_validate on public.reviews;
create trigger trg_reviews_validate before insert on public.reviews
for each row execute function public.validate_review_integrity();

create or replace function public.refresh_profile_rating()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare v_reviewee uuid := coalesce(new.reviewee_id, old.reviewee_id);
begin
  perform set_config('parkd.trusted_write', 'on', true);
  update public.profiles p set
    rating = coalesce((select round(avg(r.rating)::numeric, 2) from public.reviews r where r.reviewee_id = v_reviewee), 0),
    rating_count = (select count(*) from public.reviews r where r.reviewee_id = v_reviewee)
  where p.id = v_reviewee;
  return coalesce(new, old);
end;
$$;
drop trigger if exists trg_reviews_refresh_rating on public.reviews;
create trigger trg_reviews_refresh_rating after insert or delete on public.reviews
for each row execute function public.refresh_profile_rating();

-- Public map/search projection. It deliberately aliases no field as an exact
-- address or coordinate, and provides only data required to render a map card.
drop view if exists public.public_listing_cards;
create view public.public_listing_cards
with (security_barrier = true)
as
select
  l.id,
  l.host_id,
  ('Parking in ' || l.city) as display_name,
  l.city,
  l.country,
  case when l.postal_code is null then null else split_part(upper(l.postal_code), ' ', 1) end as postal_area,
  round(l.latitude::numeric, 2)::double precision as approximate_latitude,
  round(l.longitude::numeric, 2)::double precision as approximate_longitude,
  l.availability_mode,
  l.is_active,
  l.is_published,
  prices.min_hourly_price,
  prices.min_daily_price,
  coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', w.id, 'day_of_week', w.day_of_week,
      'start_time', w.start_time, 'end_time', w.end_time,
      'price_hour', w.price_hour, 'price_day', w.price_day
    ) order by w.day_of_week, w.start_time)
    from public.availability_weekly w where w.listing_id = l.id
  ), '[]'::jsonb) as weekly_availability,
  coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', s.id, 'start_datetime', s.start_datetime,
      'end_datetime', s.end_datetime,
      'price_hour', s.price_hour, 'price_day', s.price_day
    ) order by s.start_datetime)
    from public.availability_specific s where s.listing_id = l.id
  ), '[]'::jsonb) as specific_availability,
  hero.photo_url as hero_photo_url,
  hero.marker_x as hero_marker_x,
  hero.marker_y as hero_marker_y,
  l.created_at,
  l.updated_at
from public.listings l
left join lateral (
  select min(x.price_hour)::numeric(10,2) as min_hourly_price,
         min(x.price_day)::numeric(10,2) as min_daily_price
  from (
    select w.price_hour, w.price_day from public.availability_weekly w where w.listing_id = l.id
    union all
    select s.price_hour, s.price_day from public.availability_specific s where s.listing_id = l.id
  ) x
) prices on true
left join lateral (
  select p.photo_url, p.marker_x, p.marker_y
  from public.listing_photos p where p.listing_id = l.id
  order by p.sort_order, p.created_at limit 1
) hero on true
where l.is_active and l.is_published and l.deleted_at is null
  and not exists (
    select 1 from public.user_blocks b
    where auth.uid() is not null
      and ((b.blocker_id = auth.uid() and b.blocked_user_id = l.host_id)
        or (b.blocker_id = l.host_id and b.blocked_user_id = auth.uid()))
  );
grant select on public.public_listing_cards to anon, authenticated;

drop view if exists public.public_listing_busy_windows;
create view public.public_listing_busy_windows
with (security_barrier = true)
as
select r.listing_id, r.start_time, r.end_time
from public.reservations r
join public.listings l on l.id = r.listing_id
where l.is_active and l.is_published and l.deleted_at is null
  and (
    (r.status = 'pending' and r.checkout_expires_at > now())
    or r.status in ('confirmed', 'active')
  )
  and not exists (
    select 1 from public.user_blocks b
    where auth.uid() is not null
      and ((b.blocker_id = auth.uid() and b.blocked_user_id = l.host_id)
        or (b.blocker_id = l.host_id and b.blocked_user_id = auth.uid()))
  );
grant select on public.public_listing_busy_windows to anon, authenticated;

drop view if exists public.moderation_queue;
create view public.moderation_queue
with (security_barrier = true)
as
select r.id, r.target_type, r.target_id, r.reason, r.details, r.status,
  r.reporter_id, r.reported_user_id, p.username as reported_username,
  r.moderator_id, r.moderator_notes, r.created_at, r.updated_at, r.resolved_at
from public.reports r
left join public.profiles p on p.id = r.reported_user_id
where public.is_app_admin();
grant select on public.moderation_queue to authenticated;

drop policy if exists "listings_host_update" on public.listings;
create policy "listings_host_update" on public.listings for update
  using (host_id = auth.uid() and deleted_at is null)
  with check (host_id = auth.uid());
drop policy if exists "listings_host_delete" on public.listings;
revoke delete on public.listings from anon, authenticated;

create or replace function public.soft_delete_listing(p_listing_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;
  if exists (
    select 1 from public.reservations r where r.listing_id = p_listing_id
      and r.status in ('pending', 'confirmed', 'active')
  ) then
    raise exception using errcode = '55000', message = 'LISTING_HAS_LIVE_RESERVATIONS';
  end if;
  perform set_config('parkd.trusted_write', 'on', true);
  update public.listings set deleted_at = now(), is_active = false, is_published = false
    where id = p_listing_id and host_id = auth.uid() and deleted_at is null;
  return found;
end;
$$;
revoke all on function public.soft_delete_listing(uuid) from public;
grant execute on function public.soft_delete_listing(uuid) to authenticated;

-- Atomic account anonymization. The Edge Function deletes returned storage objects,
-- then calls auth.admin.deleteUser; retained rows no longer FK to auth.users.
create or replace function public.prepare_account_deletion(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, storage, pg_catalog
as $$
declare
  v_storage_paths jsonb;
  v_stripe_customer_id text;
begin
  if not public.is_service_role() and auth.uid() is distinct from p_user_id then
    raise exception using errcode = '42501', message = 'ACCOUNT_DELETION_NOT_AUTHORIZED';
  end if;
  if not exists (select 1 from public.profiles where id = p_user_id) then
    return jsonb_build_object('user_id', p_user_id, 'already_deleted', true,
      'stripe_customer_id', null, 'storage_objects', '[]'::jsonb);
  end if;
  perform set_config('parkd.trusted_write', 'on', true);
  select stripe_customer_id into v_stripe_customer_id
    from public.profiles where id = p_user_id;
  select coalesce(jsonb_agg(jsonb_build_object('bucket_id', bucket_id, 'name', name)), '[]'::jsonb)
    into v_storage_paths from storage.objects
    where name like p_user_id::text || '/%';
  update public.reservations set status = 'cancelled', cancelled_at = now(),
    cancellation_reason = 'account_deleted'
    where (driver_id = p_user_id or host_id = p_user_id)
      and status in ('pending', 'confirmed', 'active');
  update public.payments p set status = 'failed'
    where p.status = 'pending' and exists (
      select 1 from public.reservations r where r.id = p.reservation_id
        and r.status = 'cancelled' and r.cancellation_reason = 'account_deleted'
    );
  update public.listings set deleted_at = coalesce(deleted_at, now()),
    is_active = false, is_published = false where host_id = p_user_id;
  delete from public.messages where sender_id = p_user_id;
  delete from public.reviews where reviewer_id = p_user_id;
  delete from public.user_blocks where blocker_id = p_user_id or blocked_user_id = p_user_id;
  delete from public.payment_methods where user_id = p_user_id;
  update public.profiles set
    username = 'deleted_' || left(replace(id::text, '-', ''), 12),
    full_name = 'Deleted user', email = null, phone = null, avatar_url = null,
    birth_date = null, stripe_customer_id = null,
    deletion_requested_at = coalesce(deletion_requested_at, now()),
    deleted_at = coalesce(deleted_at, now())
  where id = p_user_id;
  return jsonb_build_object('user_id', p_user_id, 'already_deleted', false,
    'stripe_customer_id', v_stripe_customer_id, 'storage_objects', v_storage_paths);
end;
$$;
revoke all on function public.prepare_account_deletion(uuid) from public;
grant execute on function public.prepare_account_deletion(uuid) to service_role;

create or replace function public.request_account_deletion()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;
  return public.prepare_account_deletion(auth.uid());
end;
$$;
revoke all on function public.request_account_deletion() from public;
grant execute on function public.request_account_deletion() to authenticated;

-- Generic distributed fixed-window limiter for auth/geocoding/upload/payment proxies.
create table if not exists public.rate_limits (
  bucket text not null,
  subject_hash text not null,
  window_started_at timestamptz not null,
  hit_count integer not null,
  updated_at timestamptz not null default now(),
  primary key (bucket, subject_hash),
  constraint rate_limit_bucket_check check (bucket ~ '^[a-z0-9_-]{2,40}$'),
  constraint rate_limit_subject_check check (subject_hash ~ '^[a-f0-9]{64}$'),
  constraint rate_limit_hit_check check (hit_count > 0)
);
create index if not exists rate_limits_updated_idx
  on public.rate_limits(updated_at);
alter table public.rate_limits enable row level security;
revoke all on public.rate_limits from anon, authenticated;

create or replace function public.consume_rate_limit(
  p_bucket text,
  p_subject_hash text,
  p_limit integer,
  p_window_seconds integer
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare v_window timestamptz;
declare v_hits integer;
begin
  if not public.is_service_role() then
    raise exception using errcode = '42501', message = 'SERVICE_ROLE_REQUIRED';
  end if;
  p_bucket := lower(trim(p_bucket)); p_subject_hash := lower(trim(p_subject_hash));
  if p_bucket !~ '^[a-z0-9_-]{2,40}$' or p_subject_hash !~ '^[a-f0-9]{64}$'
    or p_limit not between 1 and 1000 or p_window_seconds not between 5 and 86400 then
    raise exception using errcode = '22023', message = 'INVALID_RATE_LIMIT_ARGUMENTS';
  end if;
  v_window := to_timestamp(floor(extract(epoch from now()) / p_window_seconds) * p_window_seconds);
  insert into public.rate_limits(bucket, subject_hash, window_started_at, hit_count)
    values (p_bucket, p_subject_hash, v_window, 1)
  on conflict (bucket, subject_hash) do update set
    hit_count = case when rate_limits.window_started_at = excluded.window_started_at
      then rate_limits.hit_count + 1 else 1 end,
    window_started_at = excluded.window_started_at, updated_at = now()
  returning hit_count into v_hits;
  delete from public.rate_limits where updated_at < now() - interval '48 hours';
  return v_hits <= p_limit;
end;
$$;
revoke all on function public.consume_rate_limit(text, text, integer, integer) from public;
grant execute on function public.consume_rate_limit(text, text, integer, integer) to service_role;

-- Availability checks disclose whether a private phone/username exists; only the
-- auth backend/service role may use them.
revoke execute on function public.is_username_available(text) from anon, authenticated;
revoke execute on function public.is_phone_available(text) from anon, authenticated;
revoke all on function public.is_username_available(text) from public;
revoke all on function public.is_phone_available(text) from public;
grant execute on function public.is_username_available(text) to service_role;
grant execute on function public.is_phone_available(text) to service_role;

drop policy if exists "profiles_insert_own" on public.profiles;
revoke insert on public.profiles from anon, authenticated;

drop view if exists public.public_profiles;
create view public.public_profiles as
select p.id, p.username, p.avatar_url, p.rating, p.rating_count, p.created_at
from public.profiles p
where p.deleted_at is null
  and not exists (
    select 1 from public.user_blocks b
    where auth.uid() is not null
      and ((b.blocker_id = auth.uid() and b.blocked_user_id = p.id)
        or (b.blocker_id = p.id and b.blocked_user_id = auth.uid()))
  );
grant select on public.public_profiles to anon, authenticated;

-- Private, policy-protected media buckets. Paths are:
-- listing-photos/<owner_uuid>/<listing_uuid>/<random-file> and avatars/<user_uuid>/<file>.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('listing-photos', 'listing-photos', true, 10485760, array['image/jpeg','image/png','image/webp']),
  ('avatars', 'avatars', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "parkd_listing_photos_read" on storage.objects;
create policy "parkd_listing_photos_read" on storage.objects for select
using (
  bucket_id = 'listing-photos'
  and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[^/]+$'
  and exists (
    select 1 from public.listings l
    where l.id = split_part(name, '/', 2)::uuid and l.deleted_at is null
      and (
        l.host_id = auth.uid()
        or (l.is_active and l.is_published and not exists (
          select 1 from public.user_blocks b
          where (b.blocker_id = auth.uid() and b.blocked_user_id = l.host_id)
             or (b.blocker_id = l.host_id and b.blocked_user_id = auth.uid())
        ))
        or exists (
          select 1 from public.reservations r where r.listing_id = l.id
            and r.driver_id = auth.uid() and r.status in ('confirmed','active','completed')
        )
      )
  )
);
drop policy if exists "parkd_listing_photos_insert" on storage.objects;
create policy "parkd_listing_photos_insert" on storage.objects for insert
with check (
  bucket_id = 'listing-photos'
  and split_part(name, '/', 1) = auth.uid()::text
  and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[^/]+\.(jpg|jpeg|png|webp)$'
  and lower(coalesce(metadata ->> 'mimetype', '')) in ('image/jpeg','image/png','image/webp')
  and coalesce((metadata ->> 'size')::bigint, 0) between 1 and 10485760
  and exists (
    select 1 from public.listings l
    where l.id = split_part(name, '/', 2)::uuid and l.host_id = auth.uid() and l.deleted_at is null
  )
);
drop policy if exists "parkd_listing_photos_update" on storage.objects;
create policy "parkd_listing_photos_update" on storage.objects for update
using (bucket_id = 'listing-photos' and split_part(name, '/', 1) = auth.uid()::text)
with check (bucket_id = 'listing-photos' and split_part(name, '/', 1) = auth.uid()::text);
drop policy if exists "parkd_listing_photos_delete" on storage.objects;
create policy "parkd_listing_photos_delete" on storage.objects for delete
using (bucket_id = 'listing-photos' and split_part(name, '/', 1) = auth.uid()::text);

drop policy if exists "parkd_avatars_read" on storage.objects;
create policy "parkd_avatars_read" on storage.objects for select
using (
  bucket_id = 'avatars' and name ~ '^[0-9a-f-]{36}/[^/]+$'
  and exists (select 1 from public.profiles p where p.id = split_part(name, '/', 1)::uuid and p.deleted_at is null)
);
drop policy if exists "parkd_avatars_insert" on storage.objects;
create policy "parkd_avatars_insert" on storage.objects for insert
with check (
  bucket_id = 'avatars' and split_part(name, '/', 1) = auth.uid()::text
  and name ~ '^[0-9a-f-]{36}/[^/]+\.(jpg|jpeg|png|webp)$'
  and lower(coalesce(metadata ->> 'mimetype', '')) in ('image/jpeg','image/png','image/webp')
  and coalesce((metadata ->> 'size')::bigint, 0) between 1 and 5242880
);
drop policy if exists "parkd_avatars_update" on storage.objects;
create policy "parkd_avatars_update" on storage.objects for update
using (bucket_id = 'avatars' and split_part(name, '/', 1) = auth.uid()::text)
with check (bucket_id = 'avatars' and split_part(name, '/', 1) = auth.uid()::text);
drop policy if exists "parkd_avatars_delete" on storage.objects;
create policy "parkd_avatars_delete" on storage.objects for delete
using (bucket_id = 'avatars' and split_part(name, '/', 1) = auth.uid()::text);



-- Explicit API grants and final write-side invariants. Don't rely on project-
-- specific default privileges: a fresh `supabase db reset` must behave identically.

create or replace function public.is_active_profile(p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select p_user_id is not null and exists (
    select 1 from public.profiles p where p.id = p_user_id
      and p.deleted_at is null
  );
$$;
revoke all on function public.is_active_profile(uuid) from public;
grant execute on function public.is_active_profile(uuid) to authenticated, service_role;

-- Profile creation runs once when email confirmation first occurs. Routine Auth
-- updates (last sign-in/token refresh) must not overwrite user-edited profile data.
drop trigger if exists on_auth_user_full_verification on auth.users;
create trigger on_auth_user_full_verification
after update of email_confirmed_at on auth.users
for each row
when (old.email_confirmed_at is null and new.email_confirmed_at is not null)
execute function public.ensure_profile_after_full_verification();

create or replace function public.handle_auth_user_updated()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  update public.profiles set email = new.email, updated_at = now()
  where id = new.id and deleted_at is null;
  return new;
end;
$$;

-- Earnings are private to the authenticated host and include only successful
-- payments. The baseline view otherwise exposes every host's aggregate.
create or replace view public.host_earnings
with (security_barrier = true)
as
select
  r.host_id,
  date_trunc('month', r.start_time) as month,
  count(*) filter (where r.status in ('confirmed', 'active', 'completed')) as reservation_count,
  coalesce(sum(r.total_price) filter (
    where r.status in ('confirmed', 'active', 'completed')
  ), 0) as gross_earnings
from public.reservations r
join public.payments p on p.reservation_id = r.id and p.status = 'succeeded'
where r.host_id = auth.uid()
group by r.host_id, date_trunc('month', r.start_time);

-- Base tables containing PII or exact location are never available to anonymous
-- callers. The two safe views are the anonymous read surface.
revoke all on all tables in schema public from anon;
grant select on public.public_listing_cards, public.public_listing_busy_windows,
  public.public_profiles to anon;

grant select, update on public.profiles to authenticated;
grant select, insert, update on public.listings to authenticated;
grant select, insert, update, delete on public.listing_photos to authenticated;
grant select, insert, update, delete on public.availability_weekly to authenticated;
grant select, insert, update, delete on public.availability_specific to authenticated;
grant select, update, delete on public.payment_methods to authenticated;
grant select on public.reservations, public.payments to authenticated;
grant select, update on public.conversations to authenticated;
grant select, insert, update on public.messages to authenticated;
grant select, insert on public.reviews to authenticated;
grant select, insert, delete on public.user_blocks to authenticated;
grant select, insert, update on public.reports to authenticated;
grant select on public.public_listing_cards, public.public_listing_busy_windows, public.public_profiles,
  public.host_earnings, public.moderation_queue to authenticated;

grant all on all tables in schema public to service_role;
grant usage, select on all sequences in schema public to service_role;

drop policy if exists "profiles_update_own" on public.profiles;
drop policy if exists "profiles_read_own_or_reservation_participant" on public.profiles;
create policy "profiles_read_own" on public.profiles for select
  using (auth.uid() = id);
create policy "profiles_update_own" on public.profiles for update
  using (auth.uid() = id and public.is_active_profile())
  with check (auth.uid() = id);

drop policy if exists "listings_host_insert" on public.listings;
create policy "listings_host_insert" on public.listings for insert
  with check (auth.uid() = host_id and public.is_active_profile());
drop policy if exists "listings_host_update" on public.listings;
create policy "listings_host_update" on public.listings for update
  using (auth.uid() = host_id and deleted_at is null and public.is_active_profile())
  with check (auth.uid() = host_id);

create or replace function public.guard_listing_publication()
returns trigger
language plpgsql
set search_path = public, pg_catalog
as $$
begin
  if new.deleted_at is not null then
    new.is_active := false;
    new.is_published := false;
    return new;
  end if;
  if (new.is_active or new.is_published) and (
    not new.terms_accepted or new.terms_accepted_at is null
    or not exists (select 1 from public.listing_photos p where p.listing_id = new.id)
    or (new.availability_mode = 'weekly' and not exists (
      select 1 from public.availability_weekly w where w.listing_id = new.id
    ))
    or (new.availability_mode = 'specific' and not exists (
      select 1 from public.availability_specific s where s.listing_id = new.id
    ))
  ) then
    raise exception using errcode = '23514', message = 'LISTING_NOT_READY_TO_PUBLISH';
  end if;
  return new;
end;
$$;
drop trigger if exists trg_listings_publication_guard on public.listings;
create trigger trg_listings_publication_guard before insert or update of
  is_active, is_published, terms_accepted, terms_accepted_at, deleted_at
on public.listings for each row execute function public.guard_listing_publication();

create or replace function public.validate_listing_photo_path()
returns trigger
language plpgsql
set search_path = public, pg_catalog
as $$
declare v_host uuid;
begin
  select host_id into v_host from public.listings where id = new.listing_id;
  if new.photo_url !~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[^/]+\.(jpg|jpeg|png|webp)$'
    or split_part(new.photo_url, '/', 1) <> v_host::text
    or split_part(new.photo_url, '/', 2) <> new.listing_id::text then
    raise exception using errcode = '22023', message = 'INVALID_LISTING_PHOTO_STORAGE_PATH';
  end if;
  return new;
end;
$$;
drop trigger if exists trg_listing_photos_path_guard on public.listing_photos;
create trigger trg_listing_photos_path_guard before insert or update of photo_url, listing_id
on public.listing_photos for each row execute function public.validate_listing_photo_path();

-- Rebuild write policies with active-profile checks.
drop policy if exists "availability_weekly_insert" on public.availability_weekly;
create policy "availability_weekly_insert" on public.availability_weekly for insert with check (
  public.is_active_profile() and exists (
    select 1 from public.listings l where l.id = listing_id and l.host_id = auth.uid() and l.deleted_at is null
  )
);
drop policy if exists "availability_weekly_update" on public.availability_weekly;
create policy "availability_weekly_update" on public.availability_weekly for update using (
  public.is_active_profile() and exists (
    select 1 from public.listings l where l.id = listing_id and l.host_id = auth.uid() and l.deleted_at is null
  )
);
drop policy if exists "availability_weekly_delete" on public.availability_weekly;
create policy "availability_weekly_delete" on public.availability_weekly for delete using (
  public.is_active_profile() and exists (
    select 1 from public.listings l where l.id = listing_id and l.host_id = auth.uid() and l.deleted_at is null
  )
);

drop policy if exists "availability_specific_insert" on public.availability_specific;
create policy "availability_specific_insert" on public.availability_specific for insert with check (
  public.is_active_profile() and exists (
    select 1 from public.listings l where l.id = listing_id and l.host_id = auth.uid() and l.deleted_at is null
  )
);
drop policy if exists "availability_specific_update" on public.availability_specific;
create policy "availability_specific_update" on public.availability_specific for update using (
  public.is_active_profile() and exists (
    select 1 from public.listings l where l.id = listing_id and l.host_id = auth.uid() and l.deleted_at is null
  )
);
drop policy if exists "availability_specific_delete" on public.availability_specific;
create policy "availability_specific_delete" on public.availability_specific for delete using (
  public.is_active_profile() and exists (
    select 1 from public.listings l where l.id = listing_id and l.host_id = auth.uid() and l.deleted_at is null
  )
);

drop policy if exists "listing_photos_insert" on public.listing_photos;
create policy "listing_photos_insert" on public.listing_photos for insert with check (
  public.is_active_profile() and exists (
    select 1 from public.listings l where l.id = listing_id and l.host_id = auth.uid() and l.deleted_at is null
  )
);
drop policy if exists "listing_photos_update" on public.listing_photos;
create policy "listing_photos_update" on public.listing_photos for update using (
  public.is_active_profile() and exists (
    select 1 from public.listings l where l.id = listing_id and l.host_id = auth.uid() and l.deleted_at is null
  )
);
drop policy if exists "listing_photos_delete" on public.listing_photos;
create policy "listing_photos_delete" on public.listing_photos for delete using (
  public.is_active_profile() and exists (
    select 1 from public.listings l where l.id = listing_id and l.host_id = auth.uid() and l.deleted_at is null
  )
);

drop policy if exists "payment_methods_update_own" on public.payment_methods;
create policy "payment_methods_update_own" on public.payment_methods for update
  using (auth.uid() = user_id and public.is_active_profile()) with check (auth.uid() = user_id);
drop policy if exists "payment_methods_delete_own" on public.payment_methods;
create policy "payment_methods_delete_own" on public.payment_methods for delete
  using (auth.uid() = user_id and public.is_active_profile());
create unique index if not exists payment_methods_one_default_per_user
  on public.payment_methods(user_id) where is_default;

drop policy if exists "conversations_insert_participants" on public.conversations;
revoke insert on public.conversations from authenticated;

drop policy if exists "messages_insert_participants" on public.messages;
create policy "messages_insert_participants" on public.messages for insert with check (
  sender_id = auth.uid() and public.is_active_profile() and exists (
    select 1 from public.conversations c where c.id = conversation_id
      and not c.is_closed and auth.uid() in (c.host_id, c.driver_id)
  )
);
drop policy if exists "messages_update_participants" on public.messages;
create policy "messages_update_recipient" on public.messages for update using (
  public.is_active_profile() and sender_id <> auth.uid() and exists (
    select 1 from public.conversations c where c.id = conversation_id
      and auth.uid() in (c.host_id, c.driver_id)
  )
);

drop policy if exists "reviews_insert_reviewer" on public.reviews;
create policy "reviews_insert_reviewer" on public.reviews for insert
  with check (auth.uid() = reviewer_id and public.is_active_profile());

-- Write-side abuse controls are enforced even if an attacker bypasses the UI.
-- Normal chat allows a burst of 30 messages/minute; listing creation allows five
-- drafts/hour. Edge endpoints use consume_rate_limit for their own buckets.
create or replace function public.enforce_authenticated_write_rate()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_bucket text;
  v_limit integer;
  v_window_seconds integer;
  v_subject text;
  v_window timestamptz;
  v_hits integer;
begin
  if v_user_id is null or public.is_service_role() then return new; end if;
  if tg_table_name = 'messages' then
    v_bucket := 'write_messages'; v_limit := 30; v_window_seconds := 60;
  elsif tg_table_name = 'listings' then
    v_bucket := 'write_listings'; v_limit := 5; v_window_seconds := 3600;
  else
    raise exception using errcode = '22023', message = 'UNKNOWN_RATE_LIMITED_TABLE';
  end if;
  v_subject := encode(extensions.digest(v_user_id::text, 'sha256'), 'hex');
  v_window := to_timestamp(floor(extract(epoch from now()) / v_window_seconds) * v_window_seconds);
  insert into public.rate_limits(bucket, subject_hash, window_started_at, hit_count)
    values (v_bucket, v_subject, v_window, 1)
  on conflict (bucket, subject_hash) do update set
    hit_count = case when rate_limits.window_started_at = excluded.window_started_at
      then rate_limits.hit_count + 1 else 1 end,
    window_started_at = excluded.window_started_at, updated_at = now()
  returning hit_count into v_hits;
  if v_hits > v_limit then
    raise exception using errcode = 'P0001', message = 'WRITE_RATE_LIMIT_EXCEEDED';
  end if;
  return new;
end;
$$;
revoke all on function public.enforce_authenticated_write_rate() from public;

drop trigger if exists trg_messages_rate_limit on public.messages;
create trigger trg_messages_rate_limit before insert on public.messages
for each row execute function public.enforce_authenticated_write_rate();
drop trigger if exists trg_listings_rate_limit on public.listings;
create trigger trg_listings_rate_limit before insert on public.listings
for each row execute function public.enforce_authenticated_write_rate();



-- Privacy-minimized, in-app notification outbox. This migration deliberately
-- does not add device tokens, Firebase configuration, or a push dispatcher.

do $$
begin
  create type public.notification_type as enum (
    'reservation_confirmed',
    'message_received',
    'review_received'
  );
exception
  when duplicate_object then null;
end $$;

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  actor_user_id uuid references public.profiles(id) on delete set null,
  type public.notification_type not null,
  source_entity_type text not null,
  source_entity_id uuid not null,
  data_json jsonb not null default '{}'::jsonb,
  is_read boolean not null default false,
  read_at timestamptz,
  created_at timestamptz not null default now(),

  constraint notifications_source_type_check check (
    source_entity_type in ('reservation', 'message', 'review')
  ),
  constraint notifications_data_object_check check (
    jsonb_typeof(data_json) = 'object'
  ),
  constraint notifications_read_consistency_check check (
    (not is_read and read_at is null)
    or (is_read and read_at is not null)
  )
);

create index if not exists notifications_user_feed_idx
  on public.notifications(user_id, created_at desc, id desc);
create index if not exists notifications_user_unread_idx
  on public.notifications(user_id, created_at desc)
  where not is_read;
create index if not exists notifications_actor_idx
  on public.notifications(actor_user_id)
  where actor_user_id is not null;
create unique index if not exists notifications_event_dedupe_idx
  on public.notifications(user_id, type, source_entity_type, source_entity_id);

alter table public.notifications enable row level security;

drop policy if exists "notifications_read_own" on public.notifications;
create policy "notifications_read_own"
on public.notifications for select
using (auth.uid() = user_id and public.is_active_profile());

-- Notification contents are server-owned. Clients receive SELECT plus narrow
-- SECURITY DEFINER RPCs below instead of table INSERT/UPDATE/DELETE privileges.
revoke all on public.notifications from anon, authenticated;
grant select on public.notifications to authenticated;
grant all on public.notifications to service_role;

create or replace function public.mark_notification_read(p_notification_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if auth.uid() is null or not public.is_active_profile() then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;

  update public.notifications
  set is_read = true,
      read_at = coalesce(read_at, clock_timestamp())
  where id = p_notification_id
    and user_id = auth.uid();
  return found;
end;
$$;
revoke all on function public.mark_notification_read(uuid) from public;
grant execute on function public.mark_notification_read(uuid) to authenticated;

create or replace function public.mark_all_notifications_read()
returns bigint
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_count bigint;
begin
  if auth.uid() is null or not public.is_active_profile() then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;

  update public.notifications
  set is_read = true,
      read_at = clock_timestamp()
  where user_id = auth.uid()
    and not is_read;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;
revoke all on function public.mark_all_notifications_read() from public;
grant execute on function public.mark_all_notifications_read() to authenticated;

create or replace function public.delete_notification(p_notification_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if auth.uid() is null or not public.is_active_profile() then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;

  delete from public.notifications
  where id = p_notification_id
    and user_id = auth.uid();
  return found;
end;
$$;
revoke all on function public.delete_notification(uuid) from public;
grant execute on function public.delete_notification(uuid) to authenticated;

create or replace function public.mark_message_notifications_read(
  p_reservation_id uuid
)
returns bigint
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_count bigint;
begin
  if auth.uid() is null or not public.is_active_profile() then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;

  if not exists (
    select 1 from public.reservations r
    where r.id = p_reservation_id
      and auth.uid() in (r.host_id, r.driver_id)
  ) then
    raise exception using errcode = '42501', message = 'RESERVATION_ACCESS_DENIED';
  end if;

  update public.notifications
  set is_read = true,
      read_at = clock_timestamp()
  where user_id = auth.uid()
    and type = 'message_received'
    and not is_read
    and data_json ->> 'reservation_id' = p_reservation_id::text;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;
revoke all on function public.mark_message_notifications_read(uuid) from public;
grant execute on function public.mark_message_notifications_read(uuid)
  to authenticated;

create or replace function public.notify_reservation_confirmed()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if old.status is distinct from 'confirmed'::public.reservation_status
     and new.status = 'confirmed'::public.reservation_status then
    insert into public.notifications (
      user_id, actor_user_id, type, source_entity_type, source_entity_id,
      data_json
    ) values (
      new.host_id,
      new.driver_id,
      'reservation_confirmed',
      'reservation',
      new.id,
      jsonb_build_object(
        'reservation_id', new.id,
        'listing_id', new.listing_id,
        'hub', 'hosting'
      )
    ) on conflict do nothing;
  end if;
  return new;
end;
$$;
revoke all on function public.notify_reservation_confirmed() from public;

drop trigger if exists trg_notify_reservation_confirmed on public.reservations;
create trigger trg_notify_reservation_confirmed
after update of status on public.reservations
for each row execute function public.notify_reservation_confirmed();

create or replace function public.notify_message_received()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_conversation public.conversations%rowtype;
  v_recipient uuid;
  v_hub text;
begin
  select * into v_conversation
  from public.conversations
  where id = new.conversation_id;

  if not found then
    return new;
  end if;

  if new.sender_id = v_conversation.host_id then
    v_recipient := v_conversation.driver_id;
    v_hub := 'reservations';
  elsif new.sender_id = v_conversation.driver_id then
    v_recipient := v_conversation.host_id;
    v_hub := 'hosting';
  else
    return new;
  end if;

  insert into public.notifications (
    user_id, actor_user_id, type, source_entity_type, source_entity_id,
    data_json
  ) values (
    v_recipient,
    new.sender_id,
    'message_received',
    'message',
    new.id,
    jsonb_build_object(
      'reservation_id', v_conversation.reservation_id,
      'conversation_id', new.conversation_id,
      'hub', v_hub
    )
  ) on conflict do nothing;
  return new;
end;
$$;
revoke all on function public.notify_message_received() from public;

drop trigger if exists trg_notify_message_received on public.messages;
create trigger trg_notify_message_received
after insert on public.messages
for each row execute function public.notify_message_received();

create or replace function public.notify_review_received()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_reservation public.reservations%rowtype;
  v_hub text;
begin
  select * into v_reservation
  from public.reservations
  where id = new.reservation_id;

  if not found then
    return new;
  end if;

  if new.reviewee_id = v_reservation.host_id then
    v_hub := 'hosting';
  elsif new.reviewee_id = v_reservation.driver_id then
    v_hub := 'reservations';
  else
    return new;
  end if;

  insert into public.notifications (
    user_id, actor_user_id, type, source_entity_type, source_entity_id,
    data_json
  ) values (
    new.reviewee_id,
    new.reviewer_id,
    'review_received',
    'review',
    new.id,
    jsonb_build_object(
      'reservation_id', new.reservation_id,
      'rating', new.rating,
      'hub', v_hub
    )
  ) on conflict do nothing;
  return new;
end;
$$;
revoke all on function public.notify_review_received() from public;

drop trigger if exists trg_notify_review_received on public.reviews;
create trigger trg_notify_review_received
after insert on public.reviews
for each row execute function public.notify_review_received();

-- The app anonymizes profiles rather than physically deleting them. Remove both
-- a user's inbox and notifications where they were the actor when soft deletion
-- starts, so message/review metadata is not retained elsewhere.
create or replace function public.purge_notifications_for_deleted_profile()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if tg_op = 'DELETE' then
    delete from public.notifications
    where user_id = old.id or actor_user_id = old.id;
    return old;
  end if;

  if old.deleted_at is null and new.deleted_at is not null then
    delete from public.notifications
    where user_id = old.id or actor_user_id = old.id;
  end if;
  return new;
end;
$$;
revoke all on function public.purge_notifications_for_deleted_profile()
  from public;

drop trigger if exists trg_purge_notifications_for_deleted_profile
  on public.profiles;
create trigger trg_purge_notifications_for_deleted_profile
before delete or update of deleted_at on public.profiles
for each row execute function public.purge_notifications_for_deleted_profile();

create or replace function public.purge_old_notifications(
  p_before timestamptz default now() - interval '30 days'
)
returns bigint
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_count bigint;
begin
  if not public.is_service_role() then
    raise exception using errcode = '42501', message = 'SERVICE_ROLE_REQUIRED';
  end if;
  if p_before > now() then
    raise exception using errcode = '22023', message = 'INVALID_RETENTION_CUTOFF';
  end if;

  delete from public.notifications where created_at < p_before;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;
revoke all on function public.purge_old_notifications(timestamptz) from public;
grant execute on function public.purge_old_notifications(timestamptz)
  to service_role;

-- Postgres Changes still applies table RLS for each subscriber.
do $$
begin
  alter publication supabase_realtime add table public.notifications;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.messages;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;



-- Resumable account cleanup. External identifiers are snapshotted before
-- profile anonymization so Stripe, Storage, and Auth deletion can be retried.

create table if not exists public.account_deletion_jobs (
  user_id uuid primary key,
  reason text not null default 'account_requested',
  stripe_customer_id text,
  storage_objects jsonb not null default '[]'::jsonb,
  requested_at timestamptz not null default now(),
  prepared_at timestamptz,
  lease_expires_at timestamptz,
  last_attempt_at timestamptz,
  attempt_count integer not null default 0,
  last_error text,
  completed_at timestamptz,
  constraint account_deletion_jobs_reason_check
    check (reason = 'account_requested'),
  constraint account_deletion_jobs_stripe_id_check
    check (stripe_customer_id is null or stripe_customer_id ~ '^cus_[A-Za-z0-9_]+$'),
  constraint account_deletion_jobs_storage_objects_check
    check (jsonb_typeof(storage_objects) = 'array'),
  constraint account_deletion_jobs_attempt_count_check
    check (attempt_count >= 0),
  constraint account_deletion_jobs_last_error_check
    check (last_error is null or char_length(last_error) <= 500)
);

create index if not exists account_deletion_jobs_pending_idx
  on public.account_deletion_jobs (requested_at)
  where completed_at is null;
create index if not exists account_deletion_jobs_lease_idx
  on public.account_deletion_jobs (lease_expires_at)
  where completed_at is null;

alter table public.account_deletion_jobs enable row level security;
revoke all on public.account_deletion_jobs from public, anon, authenticated;
grant all on public.account_deletion_jobs to service_role;

-- Only the service-role Edge layer can initiate destructive cleanup. In
-- particular, a signed-in client cannot bypass the delete-account handler.
create or replace function public.prepare_account_deletion(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, storage, pg_catalog
as $$
declare
  v_storage_paths jsonb;
  v_stripe_customer_id text;
  v_profile_exists boolean;
  v_already_prepared boolean;
  v_job public.account_deletion_jobs%rowtype;
begin
  if not public.is_service_role() then
    raise exception using errcode = '42501', message = 'SERVICE_ROLE_REQUIRED';
  end if;

  select exists(select 1 from public.profiles p where p.id = p_user_id),
    exists(select 1 from public.profiles p where p.id = p_user_id and p.deleted_at is not null)
  into v_profile_exists, v_already_prepared;
  select p.stripe_customer_id into v_stripe_customer_id
    from public.profiles p where p.id = p_user_id;
  select coalesce(jsonb_agg(
      jsonb_build_object('bucket_id', o.bucket_id, 'name', o.name)
      order by o.bucket_id, o.name
    ), '[]'::jsonb)
  into v_storage_paths
  from storage.objects o
  where o.bucket_id in ('avatars', 'listing-photos')
    and o.name like p_user_id::text || '/%';

  insert into public.account_deletion_jobs (
    user_id, reason, stripe_customer_id, storage_objects, requested_at
  ) values (
    p_user_id, 'account_requested', v_stripe_customer_id,
    coalesce(v_storage_paths, '[]'::jsonb), now()
  )
  on conflict (user_id) do update set
    stripe_customer_id = coalesce(
      account_deletion_jobs.stripe_customer_id,
      excluded.stripe_customer_id
    ),
    storage_objects = (
      select coalesce(jsonb_agg(distinct item.value), '[]'::jsonb)
      from jsonb_array_elements(
        account_deletion_jobs.storage_objects || excluded.storage_objects
      ) item
    );

  perform set_config('parkd.trusted_write', 'on', true);
  if v_profile_exists then
    update public.reservations set status = 'cancelled', cancelled_at = now(),
      cancellation_reason = 'account_deleted'
      where (driver_id = p_user_id or host_id = p_user_id)
        and status in ('pending', 'confirmed', 'active');
    update public.payments p set status = 'failed'
      where p.status = 'pending' and exists (
        select 1 from public.reservations r where r.id = p.reservation_id
          and r.status = 'cancelled' and r.cancellation_reason = 'account_deleted'
      );
    update public.listings set deleted_at = coalesce(deleted_at, now()),
      is_active = false, is_published = false where host_id = p_user_id;
    delete from public.messages where sender_id = p_user_id;
    delete from public.reviews where reviewer_id = p_user_id;
    delete from public.user_blocks
      where blocker_id = p_user_id or blocked_user_id = p_user_id;
    delete from public.payment_methods where user_id = p_user_id;
    update public.profiles set
      username = null,
      full_name = 'Deleted user', email = null, phone = null, avatar_url = null,
      birth_date = null, stripe_customer_id = null,
      deletion_requested_at = coalesce(deletion_requested_at, now()),
      deleted_at = coalesce(deleted_at, now())
    where id = p_user_id;
  end if;

  update public.account_deletion_jobs j set
    prepared_at = coalesce(j.prepared_at, now()),
    last_error = null
  where j.user_id = p_user_id
  returning j.* into v_job;

  return jsonb_build_object(
    'user_id', p_user_id,
    'already_deleted', not v_profile_exists or v_already_prepared,
    'stripe_customer_id', v_job.stripe_customer_id,
    'storage_objects', v_job.storage_objects,
    'prepared_at', v_job.prepared_at
  );
end;
$$;

revoke all on function public.prepare_account_deletion(uuid)
  from public, anon, authenticated;
grant execute on function public.prepare_account_deletion(uuid) to service_role;

-- The client must use the authenticated delete-account Edge Function. Remove
-- the old direct-RPC path if this migration is applied over an earlier schema.
drop function if exists public.request_account_deletion();

-- Claim a bounded batch for the scheduled Edge worker. This does not anonymize
-- profiles: external cleanup receives the captured IDs first, then explicitly
-- calls prepare_account_deletion. Incomplete/previously prepared jobs continue
-- to be returned after their short lease expires.
create function public.claim_account_deletion_jobs(
  p_limit integer default 25,
  p_now timestamptz default now()
)
returns table (
  user_id uuid,
  stripe_customer_id text,
  storage_objects jsonb,
  prepared boolean,
  attempt_count integer
)
language plpgsql
security definer
set search_path = public, storage, pg_catalog
as $$
begin
  if not public.is_service_role() then
    raise exception using errcode = '42501', message = 'SERVICE_ROLE_REQUIRED';
  end if;
  if p_limit not between 1 and 100 then
    raise exception using errcode = '22023', message = 'INVALID_CLEANUP_LIMIT';
  end if;

  -- Notification rows contain routing metadata only, but still expire after
  -- thirty days without requiring another scheduler credential or endpoint.
  perform public.purge_old_notifications(p_now - interval '30 days');

  -- Keep a non-sensitive completion tombstone after the external reconciliation
  -- snapshot expires.
  update public.account_deletion_jobs j set
    stripe_customer_id = null,
    storage_objects = '[]'::jsonb,
    last_error = null
  where j.completed_at < p_now - interval '7 days'
    and (j.stripe_customer_id is not null or j.storage_objects <> '[]'::jsonb);

  return query
  with picked as (
    select j.user_id
    from public.account_deletion_jobs j
    where j.completed_at is null
      and (j.lease_expires_at is null or j.lease_expires_at <= p_now)
    order by j.requested_at, j.user_id
    for update skip locked
    limit p_limit
  ), claimed as (
    update public.account_deletion_jobs j set
      lease_expires_at = p_now + interval '5 minutes',
      last_attempt_at = p_now,
      attempt_count = j.attempt_count + 1
    from picked
    where j.user_id = picked.user_id
    returning j.user_id, j.stripe_customer_id, j.storage_objects,
      j.prepared_at, j.attempt_count
  )
  select c.user_id, c.stripe_customer_id, c.storage_objects,
    c.prepared_at is not null, c.attempt_count
  from claimed c
  order by c.user_id;
end;
$$;

revoke all on function public.claim_account_deletion_jobs(integer, timestamptz)
  from public, anon, authenticated;
grant execute on function public.claim_account_deletion_jobs(integer, timestamptz)
  to service_role;

create or replace function public.complete_account_deletion(p_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if not public.is_service_role() then
    raise exception using errcode = '42501', message = 'SERVICE_ROLE_REQUIRED';
  end if;
  update public.account_deletion_jobs j set
    completed_at = coalesce(j.completed_at, now()),
    lease_expires_at = null,
    last_error = null
  where j.user_id = p_user_id and j.prepared_at is not null;
  return found;
end;
$$;
revoke all on function public.complete_account_deletion(uuid)
  from public, anon, authenticated;
grant execute on function public.complete_account_deletion(uuid) to service_role;

create or replace function public.record_account_deletion_failure(
  p_user_id uuid,
  p_error text
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
  update public.account_deletion_jobs j set
    lease_expires_at = null,
    last_error = left(coalesce(nullif(trim(p_error), ''), 'cleanup_failed'), 500)
  where j.user_id = p_user_id and j.completed_at is null;
  return found;
end;
$$;
revoke all on function public.record_account_deletion_failure(uuid, text)
  from public, anon, authenticated;
grant execute on function public.record_account_deletion_failure(uuid, text)
  to service_role;



-- create_checkout_session is an implementation detail of the service-role
-- prepare_reservation_checkout RPC. Supabase may grant function execution to
-- API roles through default privileges, so revoke each role explicitly.
revoke all on function public.create_checkout_session(
  uuid,
  timestamptz,
  timestamptz,
  text
) from public, anon, authenticated, service_role;



-- Soft-deleted listings must not keep blocking the same address/spot forever.
-- Publish rollback uses soft_delete_listing, so without this filter a failed
-- create leaves an invisible row that still trips the unique indexes.

drop index if exists listings_unique_address_when_no_spot;
create unique index listings_unique_address_when_no_spot
on public.listings (
  lower(trim(address)),
  lower(trim(city)),
  lower(trim(coalesce(postal_code, ''))),
  lower(trim(country))
)
where (spot_number is null or btrim(spot_number) = '')
  and deleted_at is null;

drop index if exists listings_unique_address_spot_pair;
create unique index listings_unique_address_spot_pair
on public.listings (
  lower(trim(address)),
  lower(trim(city)),
  lower(trim(coalesce(postal_code, ''))),
  lower(trim(country)),
  lower(trim(spot_number))
)
where spot_number is not null
  and btrim(spot_number) <> ''
  and deleted_at is null;



-- Flutter/Supabase Storage uploads often omit object metadata mimetype/size on
-- insert, which made parkd_listing_photos_insert (and avatars) reject valid
-- JPEGs with HTTP 400. Bucket allowed_mime_types + path extension checks remain.

drop policy if exists "parkd_listing_photos_insert" on storage.objects;
create policy "parkd_listing_photos_insert" on storage.objects for insert
with check (
  bucket_id = 'listing-photos'
  and split_part(name, '/', 1) = auth.uid()::text
  and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[^/]+\.(jpg|jpeg|png|webp)$'
  and exists (
    select 1 from public.listings l
    where l.id = split_part(name, '/', 2)::uuid
      and l.host_id = auth.uid()
      and l.deleted_at is null
  )
);

drop policy if exists "parkd_avatars_insert" on storage.objects;
create policy "parkd_avatars_insert" on storage.objects for insert
with check (
  bucket_id = 'avatars'
  and split_part(name, '/', 1) = auth.uid()::text
  and name ~ '^[0-9a-f-]{36}/[^/]+\.(jpg|jpeg|png|webp)$'
);



-- Parking walkability: expose ~111 m public coords (3 decimals) instead of
-- ~1 km (2 decimals). Halo can then stay short-walk sized without lying.

drop view if exists public.public_listing_cards;
create view public.public_listing_cards
with (security_barrier = true)
as
select
  l.id,
  l.host_id,
  ('Parking in ' || l.city) as display_name,
  l.city,
  l.country,
  case when l.postal_code is null then null else split_part(upper(l.postal_code), ' ', 1) end as postal_area,
  round(l.latitude::numeric, 3)::double precision as approximate_latitude,
  round(l.longitude::numeric, 3)::double precision as approximate_longitude,
  l.availability_mode,
  l.is_active,
  l.is_published,
  prices.min_hourly_price,
  prices.min_daily_price,
  coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', w.id, 'day_of_week', w.day_of_week,
      'start_time', w.start_time, 'end_time', w.end_time,
      'price_hour', w.price_hour, 'price_day', w.price_day
    ) order by w.day_of_week, w.start_time)
    from public.availability_weekly w where w.listing_id = l.id
  ), '[]'::jsonb) as weekly_availability,
  coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', s.id, 'start_datetime', s.start_datetime,
      'end_datetime', s.end_datetime,
      'price_hour', s.price_hour, 'price_day', s.price_day
    ) order by s.start_datetime)
    from public.availability_specific s where s.listing_id = l.id
  ), '[]'::jsonb) as specific_availability,
  hero.photo_url as hero_photo_url,
  hero.marker_x as hero_marker_x,
  hero.marker_y as hero_marker_y,
  l.created_at,
  l.updated_at
from public.listings l
left join lateral (
  select min(x.price_hour)::numeric(10,2) as min_hourly_price,
         min(x.price_day)::numeric(10,2) as min_daily_price
  from (
    select w.price_hour, w.price_day from public.availability_weekly w where w.listing_id = l.id
    union all
    select s.price_hour, s.price_day from public.availability_specific s where s.listing_id = l.id
  ) x
) prices on true
left join lateral (
  select p.photo_url, p.marker_x, p.marker_y
  from public.listing_photos p where p.listing_id = l.id
  order by p.sort_order, p.created_at limit 1
) hero on true
where l.is_active and l.is_published and l.deleted_at is null
  and not exists (
    select 1 from public.user_blocks b
    where auth.uid() is not null
      and ((b.blocker_id = auth.uid() and b.blocked_user_id = l.host_id)
        or (b.blocker_id = l.host_id and b.blocked_user_id = auth.uid()))
  );
grant select on public.public_listing_cards to anon, authenticated;



-- Host-controlled map sharing (Airbnb-style). Street address stays private on
-- public cards either way; "specific" only exposes exact map coordinates.

alter table public.listings
  add column if not exists location_sharing text not null default 'general';

alter table public.listings
  drop constraint if exists listings_location_sharing_check;

alter table public.listings
  add constraint listings_location_sharing_check
  check (location_sharing in ('general', 'specific'));

drop view if exists public.public_listing_cards;
create view public.public_listing_cards
with (security_barrier = true)
as
select
  l.id,
  l.host_id,
  ('Parking in ' || l.city) as display_name,
  l.city,
  l.country,
  case when l.postal_code is null then null else split_part(upper(l.postal_code), ' ', 1) end as postal_area,
  l.location_sharing,
  case
    when l.location_sharing = 'specific' then l.latitude
    else round(l.latitude::numeric, 3)::double precision
  end as approximate_latitude,
  case
    when l.location_sharing = 'specific' then l.longitude
    else round(l.longitude::numeric, 3)::double precision
  end as approximate_longitude,
  l.availability_mode,
  l.is_active,
  l.is_published,
  prices.min_hourly_price,
  prices.min_daily_price,
  coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', w.id, 'day_of_week', w.day_of_week,
      'start_time', w.start_time, 'end_time', w.end_time,
      'price_hour', w.price_hour, 'price_day', w.price_day
    ) order by w.day_of_week, w.start_time)
    from public.availability_weekly w where w.listing_id = l.id
  ), '[]'::jsonb) as weekly_availability,
  coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', s.id, 'start_datetime', s.start_datetime,
      'end_datetime', s.end_datetime,
      'price_hour', s.price_hour, 'price_day', s.price_day
    ) order by s.start_datetime)
    from public.availability_specific s where s.listing_id = l.id
  ), '[]'::jsonb) as specific_availability,
  hero.photo_url as hero_photo_url,
  hero.marker_x as hero_marker_x,
  hero.marker_y as hero_marker_y,
  l.created_at,
  l.updated_at
from public.listings l
left join lateral (
  select min(x.price_hour)::numeric(10,2) as min_hourly_price,
         min(x.price_day)::numeric(10,2) as min_daily_price
  from (
    select w.price_hour, w.price_day from public.availability_weekly w where w.listing_id = l.id
    union all
    select s.price_hour, s.price_day from public.availability_specific s where s.listing_id = l.id
  ) x
) prices on true
left join lateral (
  select p.photo_url, p.marker_x, p.marker_y
  from public.listing_photos p where p.listing_id = l.id
  order by p.sort_order, p.created_at limit 1
) hero on true
where l.is_active and l.is_published and l.deleted_at is null
  and not exists (
    select 1 from public.user_blocks b
    where auth.uid() is not null
      and ((b.blocker_id = auth.uid() and b.blocked_user_id = l.host_id)
        or (b.blocker_id = l.host_id and b.blocked_user_id = auth.uid()))
  );
grant select on public.public_listing_cards to anon, authenticated;



-- Driver cancel for paid upcoming reservations + optional Stripe refund bookkeeping.

alter table public.payments
  add column if not exists stripe_refund_id text;

create unique index if not exists payments_stripe_refund_id_uidx
  on public.payments (stripe_refund_id)
  where stripe_refund_id is not null;

comment on column public.payments.stripe_refund_id is
  'Stripe refund id when a succeeded payment is refunded after driver cancel.';

-- Full refund when cancellation is more than 2 hours before start.
create or replace function public.reservation_cancel_is_refundable(
  p_start_time timestamptz,
  p_now timestamptz default now()
)
returns boolean
language sql
immutable
as $$
  select p_start_time > (p_now + interval '2 hours');
$$;

revoke all on function public.reservation_cancel_is_refundable(timestamptz, timestamptz)
  from public;
grant execute on function public.reservation_cancel_is_refundable(timestamptz, timestamptz)
  to authenticated, service_role;

-- Service-role only: mark reservation cancelled and optionally mark payment refunded.
create or replace function public.apply_driver_reservation_cancellation(
  p_user_id uuid,
  p_reservation_id uuid,
  p_mark_payment_refunded boolean,
  p_stripe_refund_id text default null,
  p_reason text default 'driver_cancelled'
)
returns text
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_reservation public.reservations%rowtype;
  v_payment public.payments%rowtype;
  v_reason text;
begin
  if not public.is_service_role() then
    raise exception using errcode = '42501', message = 'SERVICE_ROLE_REQUIRED';
  end if;

  perform set_config('parkd.trusted_write', 'on', true);

  select * into v_reservation
  from public.reservations
  where id = p_reservation_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'RESERVATION_NOT_FOUND';
  end if;

  if v_reservation.driver_id is distinct from p_user_id then
    raise exception using errcode = '42501', message = 'RESERVATION_NOT_OWNED';
  end if;

  if v_reservation.status = 'cancelled' then
    return 'already_cancelled';
  end if;

  if v_reservation.status <> 'confirmed' then
    raise exception using errcode = '55000', message = 'RESERVATION_NOT_CANCELLABLE';
  end if;

  if v_reservation.start_time <= now() then
    raise exception using errcode = '55000', message = 'RESERVATION_ALREADY_STARTED';
  end if;

  v_reason := left(
    coalesce(nullif(trim(p_reason), ''), 'driver_cancelled'),
    240
  );

  update public.reservations
  set
    status = 'cancelled',
    cancelled_at = now(),
    cancellation_reason = v_reason
  where id = p_reservation_id;

  select * into v_payment
  from public.payments
  where reservation_id = p_reservation_id
  order by created_at desc
  limit 1
  for update;

  if found then
    if p_mark_payment_refunded then
      if v_payment.status not in ('succeeded', 'refunded') then
        raise exception using errcode = '55000', message = 'PAYMENT_NOT_REFUNDABLE';
      end if;
      update public.payments
      set
        status = 'refunded',
        stripe_refund_id = coalesce(
          nullif(trim(p_stripe_refund_id), ''),
          stripe_refund_id
        )
      where id = v_payment.id;
    end if;
  end if;

  return 'cancelled';
end;
$$;

revoke all on function public.apply_driver_reservation_cancellation(
  uuid, uuid, boolean, text, text
) from public;
grant execute on function public.apply_driver_reservation_cancellation(
  uuid, uuid, boolean, text, text
) to service_role;



-- Harden API surface area: SELECT-only public views, security_invoker where safe,
-- and revoke anon/authenticated EXECUTE from service-role / trigger RPCs.
-- Default privileges and role inheritance had re-opened several of these.

-- ---------------------------------------------------------------------------
-- Views
-- ---------------------------------------------------------------------------
-- host_earnings already filters to auth.uid(); run as invoker so underlying RLS
-- applies. moderation_queue needs owner rights for the reported-user profile join
-- (profiles RLS is own-row only), so it stays definer with SELECT-only grants.
-- public_* views intentionally stay SECURITY DEFINER: they redact PII / exact
-- coordinates that must not be readable via base-table RLS.

alter view public.host_earnings set (security_invoker = true, security_barrier = true);

alter view public.moderation_queue set (security_barrier = true);

alter view public.public_profiles set (security_barrier = true);

alter view public.public_listing_cards set (security_barrier = true);

alter view public.public_listing_busy_windows set (security_barrier = true);

comment on view public.public_profiles is
  'Safe public profile projection. SECURITY DEFINER is intentional so callers cannot read email/phone/stripe via profiles RLS.';
comment on view public.public_listing_cards is
  'Published listing cards with redacted/approximate coords. SECURITY DEFINER is intentional to avoid exposing listings.latitude/longitude.';
comment on view public.public_listing_busy_windows is
  'Busy windows for published listings. SECURITY DEFINER is intentional; reservations RLS is participant-only.';
comment on view public.moderation_queue is
  'Admin moderation queue. SECURITY DEFINER is intentional for reported profile username join under own-row profiles RLS.';
comment on view public.host_earnings is
  'Host monthly earnings for the signed-in user. security_invoker=true; filters to auth.uid().';

revoke all on public.host_earnings from public, anon, authenticated;
revoke all on public.moderation_queue from public, anon, authenticated;
revoke all on public.public_profiles from public, anon, authenticated;
revoke all on public.public_listing_cards from public, anon, authenticated;
revoke all on public.public_listing_busy_windows from public, anon, authenticated;

grant select on public.public_listing_cards to anon, authenticated;
grant select on public.public_listing_busy_windows to anon, authenticated;
grant select on public.public_profiles to anon, authenticated;
grant select on public.host_earnings to authenticated;
grant select on public.moderation_queue to authenticated;

-- ---------------------------------------------------------------------------
-- Helper functions: pin search_path
-- ---------------------------------------------------------------------------
alter function public.set_updated_at()
  set search_path = public, pg_catalog;
alter function public.ensure_listing_availability_mode_match()
  set search_path = public, pg_catalog;
alter function public.prevent_overlapping_availability_weekly()
  set search_path = public, pg_catalog;
alter function public.prevent_overlapping_availability_specific()
  set search_path = public, pg_catalog;
alter function public.prevent_availability_mode_switch_with_existing_rows()
  set search_path = public, pg_catalog;
alter function public.prevent_untrusted_payment_method_changes()
  set search_path = public, pg_catalog;
alter function public.set_reservation_host_id()
  set search_path = public, pg_catalog;
alter function public.assert_reservation_not_own_listing()
  set search_path = public, pg_catalog;
alter function public.prevent_overlapping_live_reservations()
  set search_path = public, pg_catalog;
alter function public.set_conversation_participants()
  set search_path = public, pg_catalog;
alter function public.prevent_untrusted_message_updates()
  set search_path = public, pg_catalog;
alter function public.request_jwt_role()
  set search_path = public, pg_catalog;
alter function public.reservation_cancel_is_refundable(timestamptz, timestamptz)
  set search_path = public, pg_catalog;

-- ---------------------------------------------------------------------------
-- Service-role-only RPCs (edge / cron / webhook). Not callable via anon JWT.
-- ---------------------------------------------------------------------------
revoke all on function public.prepare_reservation_checkout(uuid, uuid, timestamptz, timestamptz, uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.prepare_reservation_checkout(uuid, uuid, timestamptz, timestamptz, uuid, text, text)
  to service_role;

revoke all on function public.bind_checkout_payment_intent(uuid, text, uuid)
  from public, anon, authenticated;
grant execute on function public.bind_checkout_payment_intent(uuid, text, uuid)
  to service_role;

revoke all on function public.record_checkout_payment_intent(uuid, text)
  from public, anon, authenticated;
grant execute on function public.record_checkout_payment_intent(uuid, text)
  to service_role;

revoke all on function public.record_checkout_session(uuid, text)
  from public, anon, authenticated;
grant execute on function public.record_checkout_session(uuid, text)
  to service_role;

revoke all on function public.finalize_stripe_payment(text, text, text, bigint, text, timestamptz)
  from public, anon, authenticated;
grant execute on function public.finalize_stripe_payment(text, text, text, bigint, text, timestamptz)
  to service_role;

revoke all on function public.process_stripe_webhook_event(text, text, text, text, text, bigint, text, timestamptz)
  from public, anon, authenticated;
grant execute on function public.process_stripe_webhook_event(text, text, text, text, text, bigint, text, timestamptz)
  to service_role;

revoke all on function public.finalize_verified_stripe_payment(uuid, text, uuid, uuid, bigint, text)
  from public, anon, authenticated;
grant execute on function public.finalize_verified_stripe_payment(uuid, text, uuid, uuid, bigint, text)
  to service_role;

revoke all on function public.advance_reservation_lifecycle(timestamptz)
  from public, anon, authenticated;
grant execute on function public.advance_reservation_lifecycle(timestamptz)
  to service_role;

revoke all on function public.apply_driver_reservation_cancellation(uuid, uuid, boolean, text, text)
  from public, anon, authenticated;
grant execute on function public.apply_driver_reservation_cancellation(uuid, uuid, boolean, text, text)
  to service_role;

revoke all on function public.consume_rate_limit(text, text, integer, integer)
  from public, anon, authenticated;
grant execute on function public.consume_rate_limit(text, text, integer, integer)
  to service_role;

revoke all on function public.purge_old_notifications(timestamptz)
  from public, anon, authenticated;
grant execute on function public.purge_old_notifications(timestamptz)
  to service_role;

revoke all on function public.prepare_account_deletion(uuid)
  from public, anon, authenticated;
grant execute on function public.prepare_account_deletion(uuid)
  to service_role;

revoke all on function public.claim_account_deletion_jobs(integer, timestamptz)
  from public, anon, authenticated;
grant execute on function public.claim_account_deletion_jobs(integer, timestamptz)
  to service_role;

revoke all on function public.complete_account_deletion(uuid)
  from public, anon, authenticated;
grant execute on function public.complete_account_deletion(uuid)
  to service_role;

revoke all on function public.record_account_deletion_failure(uuid, text)
  from public, anon, authenticated;
grant execute on function public.record_account_deletion_failure(uuid, text)
  to service_role;

revoke all on function public.is_username_available(text)
  from public, anon, authenticated;
grant execute on function public.is_username_available(text)
  to service_role;

revoke all on function public.is_phone_available(text)
  from public, anon, authenticated;
grant execute on function public.is_phone_available(text)
  to service_role;

revoke all on function public.create_checkout_session(uuid, timestamptz, timestamptz, text)
  from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Trigger helpers: not meant to be called over PostgREST.
-- ---------------------------------------------------------------------------
revoke all on function public.notify_reservation_confirmed()
  from public, anon, authenticated;
revoke all on function public.notify_message_received()
  from public, anon, authenticated;
revoke all on function public.notify_review_received()
  from public, anon, authenticated;
revoke all on function public.purge_notifications_for_deleted_profile()
  from public, anon, authenticated;
revoke all on function public.refresh_profile_rating()
  from public, anon, authenticated;
revoke all on function public.validate_review_integrity()
  from public, anon, authenticated;
revoke all on function public.validate_report_target()
  from public, anon, authenticated;
revoke all on function public.enforce_authenticated_write_rate()
  from public, anon, authenticated;
revoke all on function public.ensure_profile_after_full_verification()
  from public, anon, authenticated;
revoke all on function public.handle_auth_user_updated()
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Authenticated-only RPCs (keep service_role; drop anon).
-- ---------------------------------------------------------------------------
revoke all on function public.cancel_checkout_hold(uuid, text)
  from public, anon;
grant execute on function public.cancel_checkout_hold(uuid, text)
  to authenticated, service_role;

revoke all on function public.mark_notification_read(uuid)
  from public, anon;
grant execute on function public.mark_notification_read(uuid)
  to authenticated, service_role;

revoke all on function public.mark_all_notifications_read()
  from public, anon;
grant execute on function public.mark_all_notifications_read()
  to authenticated, service_role;

revoke all on function public.delete_notification(uuid)
  from public, anon;
grant execute on function public.delete_notification(uuid)
  to authenticated, service_role;

revoke all on function public.mark_message_notifications_read(uuid)
  from public, anon;
grant execute on function public.mark_message_notifications_read(uuid)
  to authenticated, service_role;

revoke all on function public.set_user_block(uuid, boolean)
  from public, anon;
grant execute on function public.set_user_block(uuid, boolean)
  to authenticated, service_role;

revoke all on function public.soft_delete_listing(uuid)
  from public, anon;
grant execute on function public.soft_delete_listing(uuid)
  to authenticated, service_role;

revoke all on function public.submit_report(text, uuid, text, text)
  from public, anon;
grant execute on function public.submit_report(text, uuid, text, text)
  to authenticated, service_role;

revoke all on function public.is_active_profile(uuid)
  from public, anon;
grant execute on function public.is_active_profile(uuid)
  to authenticated, service_role;

revoke all on function public.is_app_admin(uuid)
  from public, anon;
grant execute on function public.is_app_admin(uuid)
  to authenticated, service_role;

revoke all on function public.reservation_cancel_is_refundable(timestamptz, timestamptz)
  from public, anon;
grant execute on function public.reservation_cancel_is_refundable(timestamptz, timestamptz)
  to authenticated, service_role;

-- Policy helpers still need to be readable from both JWT roles.
revoke all on function public.is_service_role() from public;
grant execute on function public.is_service_role() to anon, authenticated, service_role;

revoke all on function public.is_trusted_write() from public;
grant execute on function public.is_trusted_write() to anon, authenticated, service_role;

-- Internal tables stay API-inaccessible.
revoke all on public.checkout_idempotency from public, anon, authenticated;
revoke all on public.stripe_webhook_events from public, anon, authenticated;
revoke all on public.rate_limits from public, anon, authenticated;
revoke all on public.account_deletion_jobs from public, anon, authenticated;
revoke all on public.app_admins from public, anon, authenticated;



-- Stripe Connect Express: host payout destination (test or live).

alter table public.profiles
  add column if not exists stripe_connect_account_id text;

alter table public.profiles
  add column if not exists stripe_connect_charges_enabled boolean not null default false;

alter table public.profiles
  add column if not exists stripe_connect_details_submitted boolean not null default false;

alter table public.profiles
  drop constraint if exists profiles_stripe_connect_account_id_format;

alter table public.profiles
  add constraint profiles_stripe_connect_account_id_format
  check (
    stripe_connect_account_id is null
    or stripe_connect_account_id ~ '^acct_[A-Za-z0-9]+$'
  );

drop index if exists profiles_stripe_connect_account_id_unique;
create unique index profiles_stripe_connect_account_id_unique
  on public.profiles (stripe_connect_account_id)
  where stripe_connect_account_id is not null;

comment on column public.profiles.stripe_connect_account_id is
  'Stripe Connect Express account id. Set only by Edge Functions.';
comment on column public.profiles.stripe_connect_charges_enabled is
  'True when the Connect account can receive destination charges.';
comment on column public.profiles.stripe_connect_details_submitted is
  'True after the host finished Stripe-hosted onboarding.';

-- Keep Connect fields server-only (same path as stripe_customer_id).
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
    or new.stripe_connect_account_id is distinct from old.stripe_connect_account_id
    or new.stripe_connect_charges_enabled is distinct from old.stripe_connect_charges_enabled
    or new.stripe_connect_details_submitted is distinct from old.stripe_connect_details_submitted
    or new.deleted_at is distinct from old.deleted_at
    or new.deletion_requested_at is distinct from old.deletion_requested_at
  then
    raise exception using errcode = '42501', message = 'PROFILE_TRUSTED_FIELDS_SERVER_ONLY';
  end if;

  return new;
end;
$$;

-- Service-role helper used by Edge Functions after Stripe Account API sync.
create or replace function public.set_stripe_connect_state(
  p_user_id uuid,
  p_account_id text,
  p_charges_enabled boolean,
  p_details_submitted boolean
)
returns void
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if not public.is_service_role() then
    raise exception using errcode = '42501', message = 'SERVICE_ROLE_REQUIRED';
  end if;
  if p_account_id is null or p_account_id !~ '^acct_[A-Za-z0-9]+$' then
    raise exception using errcode = '22023', message = 'INVALID_CONNECT_ACCOUNT_ID';
  end if;

  perform set_config('parkd.trusted_write', 'on', true);

  update public.profiles
  set
    stripe_connect_account_id = p_account_id,
    stripe_connect_charges_enabled = coalesce(p_charges_enabled, false),
    stripe_connect_details_submitted = coalesce(p_details_submitted, false),
    updated_at = now()
  where id = p_user_id
    and deleted_at is null;

  if not found then
    raise exception using errcode = 'P0002', message = 'PROFILE_NOT_FOUND';
  end if;
end;
$$;

revoke all on function public.set_stripe_connect_state(uuid, text, boolean, boolean)
  from public, anon, authenticated;
grant execute on function public.set_stripe_connect_state(uuid, text, boolean, boolean)
  to service_role;



-- Require Stripe Connect payouts before a listing can go live.

create or replace function public.guard_listing_publication()
returns trigger
language plpgsql
set search_path = public, pg_catalog
as $$
begin
  if new.deleted_at is not null then
    new.is_active := false;
    new.is_published := false;
    return new;
  end if;

  if (new.is_active or new.is_published) and (
    not new.terms_accepted or new.terms_accepted_at is null
    or not exists (select 1 from public.listing_photos p where p.listing_id = new.id)
    or (new.availability_mode = 'weekly' and not exists (
      select 1 from public.availability_weekly w where w.listing_id = new.id
    ))
    or (new.availability_mode = 'specific' and not exists (
      select 1 from public.availability_specific s where s.listing_id = new.id
    ))
  ) then
    raise exception using errcode = '23514', message = 'LISTING_NOT_READY_TO_PUBLISH';
  end if;

  if (new.is_active or new.is_published) and not exists (
    select 1
    from public.profiles p
    where p.id = new.host_id
      and p.deleted_at is null
      and p.stripe_connect_account_id is not null
      and p.stripe_connect_charges_enabled
      and p.stripe_connect_details_submitted
  ) then
    raise exception using errcode = '23514', message = 'HOST_PAYOUTS_REQUIRED';
  end if;

  return new;
end;
$$;

comment on function public.guard_listing_publication() is
  'Blocks active/published listings until terms, media, availability, and host Stripe Connect payouts are ready.';



-- App updates after Connect publish gate: map discovery, reservation
-- notifications/mutes, checkout hold reuse, and publish without Connect.

-- ---------------------------------------------------------------------------
-- Hide date-specific listings from map discovery once every window has ended.
-- Weekly listings stay visible while published (recurring schedule).
-- ---------------------------------------------------------------------------

drop view if exists public.public_listing_cards;
create view public.public_listing_cards
with (security_barrier = true)
as
select
  l.id,
  l.host_id,
  ('Parking in ' || l.city) as display_name,
  l.city,
  l.country,
  case when l.postal_code is null then null else split_part(upper(l.postal_code), ' ', 1) end as postal_area,
  l.location_sharing,
  case
    when l.location_sharing = 'specific' then l.latitude
    else round(l.latitude::numeric, 3)::double precision
  end as approximate_latitude,
  case
    when l.location_sharing = 'specific' then l.longitude
    else round(l.longitude::numeric, 3)::double precision
  end as approximate_longitude,
  l.availability_mode,
  l.is_active,
  l.is_published,
  prices.min_hourly_price,
  prices.min_daily_price,
  coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', w.id, 'day_of_week', w.day_of_week,
      'start_time', w.start_time, 'end_time', w.end_time,
      'price_hour', w.price_hour, 'price_day', w.price_day
    ) order by w.day_of_week, w.start_time)
    from public.availability_weekly w where w.listing_id = l.id
  ), '[]'::jsonb) as weekly_availability,
  coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', s.id, 'start_datetime', s.start_datetime,
      'end_datetime', s.end_datetime,
      'price_hour', s.price_hour, 'price_day', s.price_day
    ) order by s.start_datetime)
    from public.availability_specific s
    where s.listing_id = l.id
      and s.end_datetime > now()
  ), '[]'::jsonb) as specific_availability,
  hero.photo_url as hero_photo_url,
  hero.marker_x as hero_marker_x,
  hero.marker_y as hero_marker_y,
  l.created_at,
  l.updated_at
from public.listings l
left join lateral (
  select min(x.price_hour)::numeric(10,2) as min_hourly_price,
         min(x.price_day)::numeric(10,2) as min_daily_price
  from (
    select w.price_hour, w.price_day from public.availability_weekly w where w.listing_id = l.id
    union all
    select s.price_hour, s.price_day from public.availability_specific s where s.listing_id = l.id
  ) x
) prices on true
left join lateral (
  select p.photo_url, p.marker_x, p.marker_y
  from public.listing_photos p where p.listing_id = l.id
  order by p.sort_order, p.created_at limit 1
) hero on true
where l.is_active and l.is_published and l.deleted_at is null
  and (
    l.availability_mode = 'weekly'
    or exists (
      select 1
      from public.availability_specific s
      where s.listing_id = l.id
        and s.end_datetime > now()
    )
  )
  and not exists (
    select 1 from public.user_blocks b
    where auth.uid() is not null
      and ((b.blocker_id = auth.uid() and b.blocked_user_id = l.host_id)
        or (b.blocker_id = l.host_id and b.blocked_user_id = auth.uid()))
  );

alter view public.public_listing_cards set (security_barrier = true);

comment on view public.public_listing_cards is
  'Published listing cards with redacted/approximate coords. Date-specific listings drop once all windows end. SECURITY DEFINER is intentional to avoid exposing listings.latitude/longitude.';

revoke all on public.public_listing_cards from public, anon, authenticated;
grant select on public.public_listing_cards to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Reservation notification read / unread (message + booking confirmed).
-- ---------------------------------------------------------------------------

create or replace function public.mark_reservation_notifications_read(
  p_reservation_id uuid
)
returns bigint
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_count bigint;
begin
  if auth.uid() is null or not public.is_active_profile() then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;

  if not exists (
    select 1 from public.reservations r
    where r.id = p_reservation_id
      and auth.uid() in (r.host_id, r.driver_id)
  ) then
    raise exception using errcode = '42501', message = 'RESERVATION_ACCESS_DENIED';
  end if;

  update public.notifications
  set is_read = true,
      read_at = clock_timestamp()
  where user_id = auth.uid()
    and not is_read
    and type in ('message_received', 'reservation_confirmed')
    and data_json ->> 'reservation_id' = p_reservation_id::text;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.mark_reservation_notifications_read(uuid)
  from public, anon;
grant execute on function public.mark_reservation_notifications_read(uuid)
  to authenticated, service_role;

create or replace function public.mark_reservation_notifications_unread(
  p_reservation_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null or not public.is_active_profile() then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;

  if not exists (
    select 1 from public.reservations r
    where r.id = p_reservation_id
      and auth.uid() in (r.host_id, r.driver_id)
  ) then
    raise exception using errcode = '42501', message = 'RESERVATION_ACCESS_DENIED';
  end if;

  select n.id
  into v_id
  from public.notifications n
  where n.user_id = auth.uid()
    and n.type in ('message_received', 'reservation_confirmed')
    and n.data_json ->> 'reservation_id' = p_reservation_id::text
  order by n.created_at desc, n.id desc
  limit 1;

  if v_id is null then
    return false;
  end if;

  update public.notifications
  set is_read = false,
      read_at = null
  where id = v_id
    and user_id = auth.uid();

  return found;
end;
$$;

revoke all on function public.mark_reservation_notifications_unread(uuid)
  from public, anon;
grant execute on function public.mark_reservation_notifications_unread(uuid)
  to authenticated, service_role;

drop function if exists public.mark_message_notifications_unread(uuid);

-- ---------------------------------------------------------------------------
-- Per-user message mute (suppresses message_received notifications only).
-- ---------------------------------------------------------------------------

create table if not exists public.reservation_message_mutes (
  user_id uuid not null references public.profiles(id) on delete cascade,
  reservation_id uuid not null references public.reservations(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, reservation_id)
);

alter table public.reservation_message_mutes enable row level security;

revoke all on public.reservation_message_mutes from anon, authenticated;
grant select on public.reservation_message_mutes to authenticated;
grant all on public.reservation_message_mutes to service_role;

drop policy if exists "reservation_message_mutes_read_own"
  on public.reservation_message_mutes;
create policy "reservation_message_mutes_read_own"
on public.reservation_message_mutes
for select
using (user_id = (select auth.uid()) and public.is_active_profile());

create or replace function public.set_reservation_messages_muted(
  p_reservation_id uuid,
  p_muted boolean
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if auth.uid() is null or not public.is_active_profile() then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;

  if not exists (
    select 1
    from public.reservations r
    where r.id = p_reservation_id
      and auth.uid() in (r.host_id, r.driver_id)
  ) then
    raise exception using errcode = '42501', message = 'RESERVATION_ACCESS_DENIED';
  end if;

  if p_muted then
    insert into public.reservation_message_mutes (user_id, reservation_id)
    values (auth.uid(), p_reservation_id)
    on conflict (user_id, reservation_id) do nothing;

    update public.notifications
    set is_read = true,
        read_at = clock_timestamp()
    where user_id = auth.uid()
      and type = 'message_received'
      and not is_read
      and data_json ->> 'reservation_id' = p_reservation_id::text;
  else
    delete from public.reservation_message_mutes
    where user_id = auth.uid()
      and reservation_id = p_reservation_id;
  end if;

  return p_muted;
end;
$$;

revoke all on function public.set_reservation_messages_muted(uuid, boolean)
  from public, anon;
grant execute on function public.set_reservation_messages_muted(uuid, boolean)
  to authenticated, service_role;

create or replace function public.notify_message_received()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_conversation public.conversations%rowtype;
  v_recipient uuid;
  v_hub text;
begin
  select * into v_conversation
  from public.conversations
  where id = new.conversation_id;

  if not found then
    return new;
  end if;

  if new.sender_id = v_conversation.host_id then
    v_recipient := v_conversation.driver_id;
    v_hub := 'reservations';
  elsif new.sender_id = v_conversation.driver_id then
    v_recipient := v_conversation.host_id;
    v_hub := 'hosting';
  else
    return new;
  end if;

  if exists (
    select 1
    from public.reservation_message_mutes m
    where m.user_id = v_recipient
      and m.reservation_id = v_conversation.reservation_id
  ) then
    return new;
  end if;

  insert into public.notifications (
    user_id, actor_user_id, type, source_entity_type, source_entity_id,
    data_json
  ) values (
    v_recipient,
    new.sender_id,
    'message_received',
    'message',
    new.id,
    jsonb_build_object(
      'reservation_id', v_conversation.reservation_id,
      'conversation_id', new.conversation_id,
      'hub', v_hub
    )
  ) on conflict do nothing;
  return new;
end;
$$;

revoke all on function public.notify_message_received() from public;

-- ---------------------------------------------------------------------------
-- Checkout hold reuse / supersede own pending hold for same window.
-- ---------------------------------------------------------------------------

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
    if v_existing.status = 'pending'
      and v_existing.checkout_expires_at is not null
      and v_existing.checkout_expires_at > now() then
      return query select v_existing.reservation_id, v_existing.payment_id,
        round(v_existing.amount_paid * 100)::bigint, v_existing.currency,
        v_existing.checkout_expires_at, v_existing.status;
      return;
    end if;
    delete from public.checkout_idempotency ci
     where ci.driver_id = v_driver_id and ci.idempotency_key = p_idempotency_key;
  end if;

  update public.reservations r
     set status = 'cancelled', cancelled_at = now(), cancellation_reason = 'checkout_expired'
   where r.status = 'pending' and r.checkout_expires_at <= now();
  update public.payments p
     set status = 'failed'
   where p.status = 'pending'
     and exists (
       select 1 from public.reservations r
       where r.id = p.reservation_id
         and r.status = 'cancelled'
         and r.cancellation_reason = 'checkout_expired'
     );

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

  update public.reservations r
     set status = 'cancelled',
         cancelled_at = now(),
         cancellation_reason = 'driver_superseded_checkout'
   where r.driver_id = v_driver_id
     and r.listing_id = p_listing_id
     and r.status = 'pending'
     and r.checkout_expires_at > now()
     and r.start_time < p_end_time
     and r.end_time > p_start_time;
  update public.payments p
     set status = 'failed'
   where p.status = 'pending'
     and exists (
       select 1 from public.reservations r
       where r.id = p.reservation_id
         and r.status = 'cancelled'
         and r.cancellation_reason = 'driver_superseded_checkout'
     );

  if exists (
    select 1
    from public.reservations o
    where o.listing_id = p_listing_id
      and o.status in ('pending', 'confirmed', 'active')
      and o.start_time < p_end_time
      and o.end_time > p_start_time
  ) then
    raise exception using errcode = '23P01', message = 'OVERLAP_RESERVATION';
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

-- ---------------------------------------------------------------------------
-- Allow publishing listings without Stripe Connect payouts setup.
-- ---------------------------------------------------------------------------

create or replace function public.guard_listing_publication()
returns trigger
language plpgsql
set search_path = public, pg_catalog
as $$
begin
  if new.deleted_at is not null then
    new.is_active := false;
    new.is_published := false;
    return new;
  end if;

  if (new.is_active or new.is_published) and (
    not new.terms_accepted or new.terms_accepted_at is null
    or not exists (select 1 from public.listing_photos p where p.listing_id = new.id)
    or (new.availability_mode = 'weekly' and not exists (
      select 1 from public.availability_weekly w where w.listing_id = new.id
    ))
    or (new.availability_mode = 'specific' and not exists (
      select 1 from public.availability_specific s where s.listing_id = new.id
    ))
  ) then
    raise exception using errcode = '23514', message = 'LISTING_NOT_READY_TO_PUBLISH';
  end if;

  return new;
end;
$$;

comment on function public.guard_listing_publication() is
  'Blocks active/published listings until terms, media, and availability are ready.';

