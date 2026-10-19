do $$
declare
  v_user_id uuid;
begin
  select user_account.id
  into v_user_id
  from auth.users as user_account
  where lower(user_account.email) = lower('dieselpetrol6@gmail.com')
  limit 1;

  if v_user_id is null then
    raise exception
      'Create dieselpetrol6@gmail.com in Supabase Authentication before running this script.';
  end if;

  insert into public.super_admins (user_id)
  values (v_user_id)
  on conflict (user_id) do nothing;
end;
$$;
