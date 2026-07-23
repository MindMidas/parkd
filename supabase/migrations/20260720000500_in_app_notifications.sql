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
