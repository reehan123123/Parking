-- 20261022090000 used "create or replace function" while adding new
-- parameters to create_tenant/create_tenant_for_request. Postgres only
-- replaces a function when the argument list matches exactly, so the old
-- 2-arg/3-arg signatures were left behind as unused, dead overloads. Drop
-- them now that nothing references them, to avoid any future PostgREST
-- "could not choose the best candidate function" ambiguity.
drop function if exists public.create_tenant(text, text);
drop function if exists public.create_tenant_for_request(text, text, uuid);

-- Fix "structure of query does not match function result type" error raised
-- by public.list_tenant_members(uuid). auth.users.email is character varying,
-- and coalesce(user_account.email, '') preserves that type instead of the
-- declared `text` return column, causing Postgres error 42804 on every call.
-- Cast the email explicitly to text to match the declared return type.
create or replace function public.list_tenant_members(p_tenant_id uuid)
returns table (
  user_id uuid,
  email text,
  role text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_super_admin() then
    raise exception using
      errcode = '42501',
      message = 'Only a Super Admin can manage tenant members.';
  end if;

  if not exists (
    select 1
    from public.tenants as tenant
    where tenant.id = p_tenant_id
  ) then
    raise exception using
      errcode = 'P0002',
      message = 'Tenant not found.';
  end if;

  return query
  select
    membership.user_id,
    coalesce(user_account.email::text, ''),
    membership.role
  from public.tenant_memberships as membership
  join auth.users as user_account on user_account.id = membership.user_id
  where membership.tenant_id = p_tenant_id
  order by membership.role, user_account.email, membership.user_id;
end;
$$;
