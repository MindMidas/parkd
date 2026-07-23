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

-- prices on availability rows only; backfill from legacy listings.price_* if those columns exist


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
