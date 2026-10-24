begin;

create or replace function public.complete_parking_notification_dispatch(
  p_event_id uuid,
  p_claim_token uuid,
  p_delivered boolean,
  p_http_status integer,
  p_message_id text,
  p_error_code text,
  p_retry_after timestamptz,
  p_now timestamptz default pg_catalog.now()
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_attempt_count smallint;
  v_claimed_at timestamptz;
  v_next_interval_at timestamptz;
  v_updated_count integer;
  v_message_id text;
begin
  if p_event_id is null
    or p_claim_token is null
    or p_delivered is null
    or p_now is null
    or (p_http_status is not null and p_http_status not between 100 and 599)
  then
    raise exception using
      errcode = '22023',
      message = 'The notification result is invalid.';
  end if;

  if p_delivered and (p_http_status is null or p_http_status not between 200 and 299) then
    raise exception using
      errcode = '22023',
      message = 'A successful notification requires a successful HTTP status.';
  end if;

  select
    notification_event.attempt_count,
    notification_event.claimed_at
  into
    v_attempt_count,
    v_claimed_at
  from public.parking_notification_events as notification_event
  where notification_event.id = p_event_id
    and notification_event.notification_type = 'expired'
    and notification_event.dispatch_status = 'sending'
    and notification_event.claim_token = p_claim_token
  for update;

  if v_attempt_count is null or v_claimed_at is null then
    return false;
  end if;

  v_next_interval_at :=
    pg_catalog.date_trunc('minute', v_claimed_at) + interval '5 minutes';

  v_message_id := case
    when p_message_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      then p_message_id
    else null
  end;

  update public.parking_notification_events as notification_event
  set
    dispatch_status = case when p_delivered then 'sent' else 'failed' end,
    claim_token = null,
    claimed_at = null,
    last_http_status = p_http_status,
    last_error_code = case
      when p_delivered then null
      when p_error_code in (
        'rate_limited',
        'upstream_5xx',
        'upstream_4xx',
        'invalid_response',
        'network_error',
        'recipient_limit',
        'configuration_error',
        'delivery_failed'
      ) then p_error_code
      else 'delivery_failed'
    end,
    last_message_id = case when p_delivered then v_message_id else null end,
    last_sent_at = case
      when p_delivered then p_now
      else notification_event.last_sent_at
    end,
    next_reminder_at = case
      when p_delivered or v_attempt_count >= 3
        then v_next_interval_at
      else notification_event.next_reminder_at
    end,
    next_attempt_at = case
      when p_delivered or v_attempt_count >= 3 then null
      else greatest(
        coalesce(p_retry_after, v_claimed_at),
        v_next_interval_at
      )
    end
  where notification_event.id = p_event_id
    and notification_event.dispatch_status = 'sending'
    and notification_event.claim_token = p_claim_token;

  get diagnostics v_updated_count = row_count;
  return v_updated_count > 0;
end;
$$;

revoke all on function public.complete_parking_notification_dispatch(
  uuid, uuid, boolean, integer, text, text, timestamptz, timestamptz
) from public, anon, authenticated;
grant execute on function public.complete_parking_notification_dispatch(
  uuid, uuid, boolean, integer, text, text, timestamptz, timestamptz
) to service_role;

commit;
