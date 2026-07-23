-- create_checkout_session is an implementation detail of the service-role
-- prepare_reservation_checkout RPC. Supabase may grant function execution to
-- API roles through default privileges, so revoke each role explicitly.
revoke all on function public.create_checkout_session(
  uuid,
  timestamptz,
  timestamptz,
  text
) from public, anon, authenticated, service_role;
