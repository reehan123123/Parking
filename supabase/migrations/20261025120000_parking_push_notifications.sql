begin;

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

create table public.parking_push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  endpoint text not null unique,
  p256dh_key text not null,
  auth_key text not null,
  locale text not null default 'en',
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  constraint parking_push_subscriptions_endpoint_check
    check (
      char_length(endpoint) <= 2048
      and endpoint ~ '^https://[^[:space:]]+$'
    ),
  constraint parking_push_subscriptions_p256dh_check
    check (p256dh_key ~ '^[A-Za-z0-9_-]{80,100}$'),
  constraint parking_push_subscriptions_auth_check
    check (auth_key ~ '^[A-Za-z0-9_-]{16,32}$'),
  constraint parking_push_subscriptions_locale_check
    check (locale in ('en', 'hi'))
);

create index parking_push_subscriptions_user_idx
  on public.parking_push_subscriptions (user_id);

alter table public.parking_push_subscriptions enable row level security;
revoke all on table public.parking_push_subscriptions
  from public, anon, authenticated;
grant select, delete
  on table public.parking_push_subscriptions
  to authenticated;

create policy "Users manage their own push subscriptions"
on public.parking_push_subscriptions
for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create or replace function public.register_parking_push_subscription(
  p_endpoint text,
  p_p256dh_key text,
  p_auth_key text,
  p_locale text default 'en'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_host text;
  v_subscription_id uuid;
  v_subscription_user_id uuid;
  v_subscription_count bigint;
begin
  if v_user_id is null then
    raise exception using
      errcode = '28000',
      message = 'An authenticated user is required.';
  end if;

  if p_endpoint is null
    or pg_catalog.char_length(p_endpoint) > 2048
    or p_endpoint !~ '^https://[^[:space:]]+$'
  then
    raise exception using
      errcode = '22023',
      message = 'The push subscription endpoint is invalid.';
  end if;

  v_host := pg_catalog.lower(
    pg_catalog.split_part(
      pg_catalog.split_part(p_endpoint, '://', 2),
      '/',
      1
    )
  );
  if v_host not in (
      'fcm.googleapis.com',
      'updates.push.services.mozilla.com',
      'web.push.apple.com'
    )
    and v_host not like '%.notify.windows.com'
  then
    raise exception using
      errcode = '22023',
      message = 'The push subscription provider is not supported.';
  end if;

  if p_p256dh_key is null
    or p_p256dh_key !~ '^[A-Za-z0-9_-]{80,100}$'
    or p_auth_key is null
    or p_auth_key !~ '^[A-Za-z0-9_-]{16,32}$'
    or p_locale is null
    or p_locale not in ('en', 'hi')
  then
    raise exception using
      errcode = '22023',
      message = 'The push subscription keys or locale are invalid.';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_user_id::text, 0)
  );

  select subscription.id, subscription.user_id
  into v_subscription_id, v_subscription_user_id
  from public.parking_push_subscriptions as subscription
  where subscription.endpoint = p_endpoint
  for update;

  if v_subscription_id is not null then
    if v_subscription_user_id <> v_user_id then
      raise exception using
        errcode = '42501',
        message = 'PUSH_ENDPOINT_IN_USE';
    end if;

    update public.parking_push_subscriptions as subscription
    set
      p256dh_key = p_p256dh_key,
      auth_key = p_auth_key,
      locale = p_locale,
      updated_at = pg_catalog.now()
    where subscription.id = v_subscription_id;
    return v_subscription_id;
  end if;

  select pg_catalog.count(*)
  into v_subscription_count
  from public.parking_push_subscriptions as subscription
  where subscription.user_id = v_user_id;

  if v_subscription_count >= 10 then
    raise exception using
      errcode = '23514',
      message = 'PUSH_SUBSCRIPTION_LIMIT_REACHED';
  end if;

  insert into public.parking_push_subscriptions (
    user_id,
    endpoint,
    p256dh_key,
    auth_key,
    locale
  )
  values (
    v_user_id,
    p_endpoint,
    p_p256dh_key,
    p_auth_key,
    p_locale
  )
  returning id into v_subscription_id;

  return v_subscription_id;
end;
$$;

revoke all on function public.register_parking_push_subscription(
  text, text, text, text
) from public, anon;
grant execute on function public.register_parking_push_subscription(
  text, text, text, text
) to authenticated;

create table public.parking_notification_events (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null
    references public.parking_sessions(id) on delete cascade,
  notification_type text not null,
  due_at timestamptz not null,
  created_at timestamptz not null default pg_catalog.now(),
  constraint parking_notification_events_type_check
    check (notification_type in ('ninety_percent', 'expired')),
  constraint parking_notification_events_session_type_key
    unique (session_id, notification_type)
);

create index parking_notification_events_due_idx
  on public.parking_notification_events (due_at, id);

create table public.parking_notification_deliveries (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null
    references public.parking_notification_events(id) on delete cascade,
  subscription_id uuid not null
    references public.parking_push_subscriptions(id) on delete cascade,
  status text not null default 'pending',
  attempted_at timestamptz,
  delivered_at timestamptz,
  error_code text,
  created_at timestamptz not null default pg_catalog.now(),
  constraint parking_notification_deliveries_status_check
    check (status in ('pending', 'sending', 'sent', 'failed', 'skipped')),
  constraint parking_notification_deliveries_event_subscription_key
    unique (event_id, subscription_id)
);

create index parking_notification_deliveries_pending_idx
  on public.parking_notification_deliveries (status, created_at, id);

alter table public.parking_notification_events enable row level security;
alter table public.parking_notification_deliveries enable row level security;
revoke all on table public.parking_notification_events,
  public.parking_notification_deliveries
  from public, anon, authenticated;
grant all on table public.parking_notification_events,
  public.parking_notification_deliveries
  to service_role;

create or replace function public.claim_due_parking_notification_deliveries(
  p_now timestamptz default pg_catalog.now()
)
returns table (
  delivery_id uuid,
  subscription_id uuid,
  session_id uuid,
  tenant_id uuid,
  notification_type text,
  endpoint text,
  p256dh_key text,
  auth_key text,
  locale text,
  can_mark_paid boolean,
  remaining_balance numeric
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_now is null then
    raise exception using
      errcode = '22023',
      message = 'The notification claim time is required.';
  end if;

  update public.parking_notification_deliveries as delivery
  set
    status = 'failed',
    error_code = 'dispatch_interrupted'
  where delivery.status = 'sending'
    and delivery.attempted_at < p_now - interval '10 minutes';

  with due_events as (
    select
      session.id as session_id,
      'ninety_percent'::text as notification_type,
      session.entry_time
        + (session.expires_at - session.entry_time) * 0.9 as due_at
    from public.parking_sessions as session
    join public.tenants as tenant on tenant.id = session.tenant_id
    where session.expires_at > session.entry_time
      and session.total_charge > session.paid_amount
      and tenant.archived_at is null
      and tenant.valid_until >=
        (p_now at time zone 'Asia/Kolkata')::date
      and p_now >= session.entry_time
        + (session.expires_at - session.entry_time) * 0.9
      and p_now < session.expires_at

    union all

    select
      session.id as session_id,
      'expired'::text as notification_type,
      session.expires_at as due_at
    from public.parking_sessions as session
    join public.tenants as tenant on tenant.id = session.tenant_id
    where session.expires_at > session.entry_time
      and session.total_charge > session.paid_amount
      and tenant.archived_at is null
      and tenant.valid_until >=
        (p_now at time zone 'Asia/Kolkata')::date
      and p_now >= session.expires_at
  ),
  inserted_events as (
    insert into public.parking_notification_events (
      session_id,
      notification_type,
      due_at
    )
    select
      due_events.session_id,
      due_events.notification_type,
      due_events.due_at
    from due_events
    on conflict (session_id, notification_type) do nothing
    returning id, session_id
  )
  insert into public.parking_notification_deliveries (
    event_id,
    subscription_id
  )
  select
    inserted_events.id,
    subscription.id
  from inserted_events
  join public.parking_sessions as session
    on session.id = inserted_events.session_id
  join public.tenants as tenant
    on tenant.id = session.tenant_id
   and tenant.archived_at is null
   and tenant.valid_until >=
     (p_now at time zone 'Asia/Kolkata')::date
  join public.tenant_memberships as membership
    on membership.tenant_id = session.tenant_id
   and (membership.role = 'owner' or membership.can_view_entries)
  join public.parking_push_subscriptions as subscription
    on subscription.user_id = membership.user_id
  on conflict (event_id, subscription_id) do nothing;

  update public.parking_notification_deliveries as delivery
  set
    status = 'skipped',
    error_code = 'notification_no_longer_eligible'
  from public.parking_notification_events as notification_event,
       public.parking_sessions as session,
       public.parking_push_subscriptions as subscription,
       public.tenants as tenant
  where delivery.event_id = notification_event.id
    and session.id = notification_event.session_id
    and subscription.id = delivery.subscription_id
    and tenant.id = session.tenant_id
    and delivery.status = 'pending'
    and (
      session.total_charge <= session.paid_amount
      or tenant.archived_at is not null
      or tenant.valid_until <
        (p_now at time zone 'Asia/Kolkata')::date
      or not exists (
        select 1
        from public.tenant_memberships as membership
        where membership.tenant_id = session.tenant_id
          and membership.user_id = subscription.user_id
          and (membership.role = 'owner' or membership.can_view_entries)
      )
    );

  return query
  with eligible_deliveries as (
    select
      delivery.id as delivery_id,
      subscription.id as subscription_id,
      session.id as session_id,
      session.tenant_id,
      notification_event.notification_type,
      subscription.endpoint,
      subscription.p256dh_key,
      subscription.auth_key,
      subscription.locale,
      (membership.role = 'owner' or membership.can_edit_entries)
        as can_mark_paid,
      session.total_charge - session.paid_amount as remaining_balance,
      notification_event.due_at
    from public.parking_notification_deliveries as delivery
    join public.parking_notification_events as notification_event
      on notification_event.id = delivery.event_id
    join public.parking_sessions as session
      on session.id = notification_event.session_id
    join public.tenants as tenant
      on tenant.id = session.tenant_id
    join public.parking_push_subscriptions as subscription
      on subscription.id = delivery.subscription_id
    join public.tenant_memberships as membership
      on membership.tenant_id = session.tenant_id
     and membership.user_id = subscription.user_id
     and (membership.role = 'owner' or membership.can_view_entries)
    where delivery.status = 'pending'
      and session.total_charge > session.paid_amount
      and tenant.archived_at is null
      and tenant.valid_until >=
        (p_now at time zone 'Asia/Kolkata')::date
    order by notification_event.due_at, delivery.id
    for update of delivery skip locked
    limit 200
  ),
  claimed_deliveries as (
    update public.parking_notification_deliveries as delivery
    set
      status = 'sending',
      attempted_at = p_now
    from eligible_deliveries as eligible
    where delivery.id = eligible.delivery_id
    returning delivery.id
  )
  select
    eligible.delivery_id,
    eligible.subscription_id,
    eligible.session_id,
    eligible.tenant_id,
    eligible.notification_type,
    eligible.endpoint,
    eligible.p256dh_key,
    eligible.auth_key,
    eligible.locale,
    eligible.can_mark_paid,
    eligible.remaining_balance
  from eligible_deliveries as eligible
  join claimed_deliveries
    on claimed_deliveries.id = eligible.delivery_id;
end;
$$;

revoke all on function public.claim_due_parking_notification_deliveries(
  timestamptz
) from public, anon, authenticated;
grant execute on function public.claim_due_parking_notification_deliveries(
  timestamptz
) to service_role;

create or replace function public.mark_parking_session_fully_paid(
  p_session_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant_id uuid;
  v_updated_count integer;
begin
  if p_session_id is null then
    raise exception using
      errcode = '22023',
      message = 'A parking session id is required.';
  end if;

  select session.tenant_id
  into v_tenant_id
  from public.parking_sessions as session
  where session.id = p_session_id;

  if v_tenant_id is null then
    return false;
  end if;

  if not public.can_edit_tenant_entries(v_tenant_id) then
    raise exception using
      errcode = '42501',
      message = 'Parking entry edit permission is required.';
  end if;

  update public.parking_sessions as session
  set paid_amount = session.total_charge
  where session.id = p_session_id
    and session.total_charge > session.paid_amount;

  get diagnostics v_updated_count = row_count;

  if v_updated_count > 0 then
    update public.parking_notification_deliveries as delivery
    set
      status = 'skipped',
      error_code = 'parking_session_marked_paid'
    from public.parking_notification_events as notification_event
    where notification_event.id = delivery.event_id
      and notification_event.session_id = p_session_id
      and delivery.status in ('pending', 'sending');
  end if;

  return v_updated_count > 0;
end;
$$;

revoke all on function public.mark_parking_session_fully_paid(uuid)
  from public, anon;
grant execute on function public.mark_parking_session_fully_paid(uuid)
  to authenticated;

select cron.schedule(
  'parking-push-dispatch',
  '* * * * *',
  $cron$
    select net.http_post(
      url := project_url.decrypted_secret
        || '/functions/v1/dispatch-parking-notifications',
      headers := jsonb_build_object(
        'Content-Type',
        'application/json',
        'x-parking-notification-secret',
        cron_secret.decrypted_secret
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 10000
    )
    from vault.decrypted_secrets as project_url
    cross join vault.decrypted_secrets as cron_secret
    where project_url.name = 'parking_notifications_project_url'
      and cron_secret.name = 'parking_notifications_cron_secret';
  $cron$
);

commit;
