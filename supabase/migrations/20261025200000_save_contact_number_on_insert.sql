begin;

create function public.create_parking_session(
  p_tenant_id uuid,
  p_plate_number text,
  p_entry_time timestamptz,
  p_allowed_duration_value integer,
  p_allowed_duration_unit text,
  p_expires_at timestamptz,
  p_total_charge numeric,
  p_paid_amount numeric,
  p_has_photo boolean,
  p_contact_number text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_session_id uuid;
  v_plate_number text := pg_catalog.upper(pg_catalog.btrim(p_plate_number));
begin
  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required.';
  end if;

  if p_tenant_id is null
    or v_plate_number is null
    or pg_catalog.char_length(v_plate_number) not between 1 and 64
    or p_entry_time is null
    or p_allowed_duration_value is null
    or p_allowed_duration_value <= 0
    or p_allowed_duration_unit not in ('minutes', 'hours', 'days', 'months')
    or p_expires_at is null
    or p_expires_at <= p_entry_time
    or p_total_charge is null
    or p_total_charge < 0
    or p_paid_amount is null
    or p_paid_amount < 0
    or p_paid_amount > p_total_charge
    or p_has_photo is null
    or p_contact_number is null
    or p_contact_number !~ '^\+91[6-9][0-9]{9}$'
  then
    raise exception using
      errcode = '22023',
      message = 'The parking-session values are invalid.';
  end if;

  if not public.can_add_tenant_entries(p_tenant_id) then
    raise exception using
      errcode = '42501',
      message = 'You do not have permission to add parking entries.';
  end if;

  insert into public.parking_sessions (
    tenant_id,
    plate_number,
    entry_time,
    allowed_duration_value,
    allowed_duration_unit,
    expires_at,
    created_by,
    total_charge,
    paid_amount,
    contact_number,
    photo_upload_pending
  )
  values (
    p_tenant_id,
    v_plate_number,
    p_entry_time,
    p_allowed_duration_value,
    p_allowed_duration_unit,
    p_expires_at,
    v_user_id,
    p_total_charge,
    p_paid_amount,
    p_contact_number,
    p_has_photo
  )
  returning id into v_session_id;

  return v_session_id;
end;
$$;

revoke all on function public.create_parking_session(
  uuid,
  text,
  timestamptz,
  integer,
  text,
  timestamptz,
  numeric,
  numeric,
  boolean,
  text
) from public, anon;
grant execute on function public.create_parking_session(
  uuid,
  text,
  timestamptz,
  integer,
  text,
  timestamptz,
  numeric,
  numeric,
  boolean,
  text
) to authenticated;

commit;
