-- Moderation, content integrity, soft deletion, demo retention, and storage RLS.

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

create or replace function public.purge_expired_demo_data(p_now timestamptz default now())
returns table (user_id uuid, cleanup_result jsonb)
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare v_user_id uuid;
begin
  if not public.is_service_role() then
    raise exception using errcode = '42501', message = 'SERVICE_ROLE_REQUIRED';
  end if;
  for v_user_id in
    select p.id from public.profiles p
    where p.is_demo and p.deleted_at is null and p.demo_expires_at <= p_now
    order by p.demo_expires_at for update skip locked
  loop
    user_id := v_user_id;
    cleanup_result := public.prepare_account_deletion(v_user_id);
    return next;
  end loop;
end;
$$;
revoke all on function public.purge_expired_demo_data(timestamptz) from public;
grant execute on function public.purge_expired_demo_data(timestamptz) to service_role;

-- Generic distributed fixed-window limiter for auth/geocoding/upload/payment proxies.
create table if not exists public.demo_rate_limits (
  bucket text not null,
  subject_hash text not null,
  window_started_at timestamptz not null,
  hit_count integer not null,
  updated_at timestamptz not null default now(),
  primary key (bucket, subject_hash),
  constraint demo_rate_limit_bucket_check check (bucket ~ '^[a-z0-9_-]{2,40}$'),
  constraint demo_rate_limit_subject_check check (subject_hash ~ '^[a-f0-9]{64}$'),
  constraint demo_rate_limit_hit_check check (hit_count > 0)
);
create index if not exists demo_rate_limits_updated_idx
  on public.demo_rate_limits(updated_at);
alter table public.demo_rate_limits enable row level security;
revoke all on public.demo_rate_limits from anon, authenticated;

create or replace function public.consume_demo_rate_limit(
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
  insert into public.demo_rate_limits(bucket, subject_hash, window_started_at, hit_count)
    values (p_bucket, p_subject_hash, v_window, 1)
  on conflict (bucket, subject_hash) do update set
    hit_count = case when demo_rate_limits.window_started_at = excluded.window_started_at
      then demo_rate_limits.hit_count + 1 else 1 end,
    window_started_at = excluded.window_started_at, updated_at = now()
  returning hit_count into v_hits;
  delete from public.demo_rate_limits where updated_at < now() - interval '48 hours';
  return v_hits <= p_limit;
end;
$$;
revoke all on function public.consume_demo_rate_limit(text, text, integer, integer) from public;
grant execute on function public.consume_demo_rate_limit(text, text, integer, integer) to service_role;

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
