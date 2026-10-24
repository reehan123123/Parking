begin;

drop function if exists public.get_parking_notification_dispatch_target(
  uuid,
  uuid,
  timestamptz
);

create function public.get_parking_notification_dispatch_target(
  p_event_id uuid,
  p_claim_token uuid,
  p_now timestamptz default pg_catalog.now()
)
returns table (
  event_id uuid,
  session_id uuid,
  tenant_id uuid,
  idempotency_key uuid,
  recipient_external_ids uuid[],
  plate_number text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session_id uuid;
  v_tenant_id uuid;
  v_plate_number text;
  v_recipient_ids uuid[];
begin
  if p_event_id is null or p_claim_token is null or p_now is null then
    raise exception using
      errcode = '22023',
      message = 'A valid notification claim is required.';
  end if;

  select session.id, session.tenant_id, session.plate_number
  into v_session_id, v_tenant_id, v_plate_number
  from public.parking_notification_events as notification_event
  join public.parking_sessions as session
    on session.id = notification_event.session_id
  where notification_event.id = p_event_id
    and notification_event.notification_type = 'expired'
    and notification_event.dispatch_status = 'sending'
    and notification_event.claim_token = p_claim_token
  for update of notification_event;

  if v_session_id is null then
    return;
  end if;

  if not exists (
    select 1
    from public.parking_sessions as session
    join public.tenants as tenant on tenant.id = session.tenant_id
    where session.id = v_session_id
      and session.expires_at <= p_now
      and session.expires_at > session.entry_time
      and session.total_charge > session.paid_amount
      and tenant.archived_at is null
      and tenant.valid_until >=
        (p_now at time zone 'Asia/Kolkata')::date
  ) then
    update public.parking_notification_events as notification_event
    set
      dispatch_status = 'resolved',
      claim_token = null,
      claimed_at = null,
      next_attempt_at = null,
      idempotency_key = null,
      attempt_count = 0,
      last_error_code = null
    where notification_event.id = p_event_id
      and notification_event.claim_token = p_claim_token;

    update public.parking_in_app_notifications as notification
    set resolved_at = p_now
    where notification.session_id = v_session_id
      and notification.resolved_at is null;

    return;
  end if;

  select pg_catalog.array_agg(
    distinct membership.user_id order by membership.user_id
  )
  into v_recipient_ids
  from public.tenant_memberships as membership
  where membership.tenant_id = v_tenant_id
    and (membership.role = 'owner' or membership.can_view_entries);

  if v_recipient_ids is null or pg_catalog.cardinality(v_recipient_ids) = 0 then
    update public.parking_notification_events as notification_event
    set
      dispatch_status = 'pending',
      claim_token = null,
      claimed_at = null,
      next_attempt_at = null,
      last_error_code = 'no_authorized_recipients'
    where notification_event.id = p_event_id
      and notification_event.claim_token = p_claim_token;

    update public.parking_in_app_notifications as notification
    set resolved_at = p_now
    where notification.session_id = v_session_id
      and notification.resolved_at is null
      and not exists (
        select 1
        from public.tenant_memberships as membership
        where membership.tenant_id = notification.tenant_id
          and membership.user_id = notification.recipient_user_id
          and (membership.role = 'owner' or membership.can_view_entries)
      );

    return;
  end if;

  return query
  select
    notification_event.id,
    notification_event.session_id,
    v_tenant_id,
    notification_event.idempotency_key,
    v_recipient_ids,
    v_plate_number
  from public.parking_notification_events as notification_event
  where notification_event.id = p_event_id
    and notification_event.dispatch_status = 'sending'
    and notification_event.claim_token = p_claim_token;
end;
$$;

revoke all on function public.get_parking_notification_dispatch_target(
  uuid, uuid, timestamptz
) from public, anon, authenticated;
grant execute on function public.get_parking_notification_dispatch_target(
  uuid, uuid, timestamptz
) to service_role;

create function public.mark_all_parking_in_app_notifications_read(
  p_tenant_id uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_updated_count integer;
begin
  if v_user_id is null then
    raise exception using
      errcode = '28000',
      message = 'An authenticated user is required.';
  end if;

  if p_tenant_id is null then
    raise exception using
      errcode = '22023',
      message = 'A tenant id is required.';
  end if;

  update public.parking_in_app_notifications as notification
  set read_at = pg_catalog.now()
  where notification.tenant_id = p_tenant_id
    and notification.recipient_user_id = v_user_id
    and notification.resolved_at is null
    and notification.read_at is null
    and public.can_view_tenant_entries(notification.tenant_id);

  get diagnostics v_updated_count = row_count;
  return v_updated_count;
end;
$$;

revoke all on function
  public.mark_all_parking_in_app_notifications_read(uuid)
  from public, anon;
grant execute on function
  public.mark_all_parking_in_app_notifications_read(uuid)
  to authenticated;

commit;
