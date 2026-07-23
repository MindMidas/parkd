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
