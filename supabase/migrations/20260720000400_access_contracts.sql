-- Explicit API grants and final write-side invariants. Do not depend on project-
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
      and (not p.is_demo or p.demo_expires_at > now())
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
-- test payments. The baseline view otherwise exposes every host's aggregate.
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

-- Rebuild write policies with active-demo checks.
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
-- drafts/hour. Edge endpoints use consume_demo_rate_limit for their own buckets.
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
  v_subject := encode(digest(v_user_id::text, 'sha256'), 'hex');
  v_window := to_timestamp(floor(extract(epoch from now()) / v_window_seconds) * v_window_seconds);
  insert into public.demo_rate_limits(bucket, subject_hash, window_started_at, hit_count)
    values (v_bucket, v_subject, v_window, 1)
  on conflict (bucket, subject_hash) do update set
    hit_count = case when demo_rate_limits.window_started_at = excluded.window_started_at
      then demo_rate_limits.hit_count + 1 else 1 end,
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
