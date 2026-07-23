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
