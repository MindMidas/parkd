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
