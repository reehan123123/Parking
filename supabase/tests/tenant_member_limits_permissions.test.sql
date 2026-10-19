begin;

select no_plan();

insert into auth.users (id, email)
values
  ('71111111-1111-4111-8111-111111111111', 'member-owner@example.com'),
  ('72222222-2222-4222-8222-222222222222', 'limited-member@example.com'),
  ('73333333-3333-4333-8333-333333333333', 'second-member@example.com'),
  ('74444444-4444-4444-8444-444444444444', 'member-admin@example.com'),
  ('75555555-5555-4555-8555-555555555555', 'other-owner@example.com');

insert into public.tenants (id, name, slug, created_by, valid_until)
values
  (
    'a1111111-1111-4111-8111-111111111111',
    'Member policy workspace',
    'member-policy-workspace',
    '71111111-1111-4111-8111-111111111111',
    (now() at time zone 'Asia/Kolkata')::date + 3650
  ),
  (
    'a2222222-2222-4222-8222-222222222222',
    'Member isolation workspace',
    'member-isolation-workspace',
    '75555555-5555-4555-8555-555555555555',
    (now() at time zone 'Asia/Kolkata')::date + 3650
  );

insert into public.tenant_memberships (tenant_id, user_id, role)
values
  (
    'a1111111-1111-4111-8111-111111111111',
    '71111111-1111-4111-8111-111111111111',
    'owner'
  ),
  (
    'a1111111-1111-4111-8111-111111111111',
    '75555555-5555-4555-8555-555555555555',
    'owner'
  ),
  (
    'a2222222-2222-4222-8222-222222222222',
    '75555555-5555-4555-8555-555555555555',
    'owner'
  );

insert into public.super_admins (user_id)
values ('74444444-4444-4444-8444-444444444444');

insert into public.device_sessions (
  tenant_id,
  user_id,
  auth_session_id,
  installation_id
)
values
  (
    'a1111111-1111-4111-8111-111111111111',
    '71111111-1111-4111-8111-111111111111',
    '81111111-1111-4111-8111-111111111111',
    '91111111-1111-4111-8111-111111111111'
  ),
  (
    'a1111111-1111-4111-8111-111111111111',
    '72222222-2222-4222-8222-222222222222',
    '82222222-2222-4222-8222-222222222222',
    '92222222-2222-4222-8222-222222222222'
  );

insert into public.parking_sessions (
  id,
  tenant_id,
  plate_number,
  entry_time,
  allowed_duration_value,
  allowed_duration_unit,
  expires_at,
  created_by
)
values
  (
    'c1111111-1111-4111-8111-111111111111',
    'a1111111-1111-4111-8111-111111111111',
    'OWNER-ENTRY',
    now(),
    1,
    'hours',
    now() + interval '1 hour',
    '71111111-1111-4111-8111-111111111111'
  ),
  (
    'c2222222-2222-4222-8222-222222222222',
    'a2222222-2222-4222-8222-222222222222',
    'OTHER-ENTRY',
    now(),
    1,
    'hours',
    now() + interval '1 hour',
    '75555555-5555-4555-8555-555555555555'
  );

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '71111111-1111-4111-8111-111111111111',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "71111111-1111-4111-8111-111111111111",
    "role": "authenticated",
    "session_id": "81111111-1111-4111-8111-111111111111",
    "app_metadata": {}
  }',
  true
);

select is(
  (
    select member_limit
    from public.tenants
    where id = 'a1111111-1111-4111-8111-111111111111'
  ),
  1,
  'new tenants default to one member excluding owners'
);
select is(
  (
    select member_limit
    from public.get_tenant_member_capacity(
      'a1111111-1111-4111-8111-111111111111'
    )
  ),
  1,
  'the owner can read the tenant member limit'
);
select is(
  (
    select active_member_count
    from public.get_tenant_member_capacity(
      'a1111111-1111-4111-8111-111111111111'
    )
  ),
  0,
  'tenant owners do not consume member capacity'
);
select is(
  (
    select remaining_member_count
    from public.get_tenant_member_capacity(
      'a1111111-1111-4111-8111-111111111111'
    )
  ),
  1,
  'an unused tenant starts with one remaining member slot'
);
select is(
  (select count(*) from public.list_tenant_members(
    'a1111111-1111-4111-8111-111111111111'
  )),
  2::bigint,
  'a tenant owner can list members of their own tenant'
);
select throws_ok(
  $$select public.add_tenant_member(
      'a1111111-1111-4111-8111-111111111111',
      'limited-member@example.com',
      'member'
    )$$,
  'P0001',
  'MEMBER_LIMIT_REACHED',
  'the default member slot cannot be exceeded'
);
select throws_ok(
  $$select * from public.set_tenant_member_limit(
      'a1111111-1111-4111-8111-111111111111',
      2
    )$$,
  '42501',
  null,
  'tenant owners cannot change member limits'
);
select throws_ok(
  $$select public.add_tenant_member(
      'a1111111-1111-4111-8111-111111111111',
      'second-member@example.com',
      'owner'
    )$$,
  '42501',
  null,
  'tenant owners cannot add owner-role accounts'
);

select set_config(
  'request.jwt.claim.sub',
  '74444444-4444-4444-8444-444444444444',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "74444444-4444-4444-8444-444444444444",
    "role": "authenticated",
    "session_id": "84444444-4444-4444-8444-444444444444",
    "app_metadata": {}
  }',
  true
);
select ok(public.is_super_admin(), 'a platform administrator is recognized');
select lives_ok(
  $$select * from public.set_tenant_member_limit(
      'a1111111-1111-4111-8111-111111111111',
      2
    )$$,
  'a Super Admin can raise the tenant member limit'
);
select throws_ok(
  $$select * from public.set_tenant_member_limit(
      'a1111111-1111-4111-8111-111111111111',
      51
    )$$,
  '22023',
  null,
  'the member limit is capped at fifty'
);
select throws_ok(
  $$select * from public.set_tenant_member_limit(
      'a1111111-1111-4111-8111-111111111111',
      0
    )$$,
  '22023',
  null,
  'the member limit must be positive'
);
select is(
  (select count(*) from public.list_tenant_member_capacities()),
  2::bigint,
  'Super Admins can list usage across tenants'
);

select set_config(
  'request.jwt.claim.sub',
  '71111111-1111-4111-8111-111111111111',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "71111111-1111-4111-8111-111111111111",
    "role": "authenticated",
    "session_id": "81111111-1111-4111-8111-111111111111",
    "app_metadata": {}
  }',
  true
);
select lives_ok(
  $$select public.add_tenant_member(
      'a1111111-1111-4111-8111-111111111111',
      'limited-member@example.com',
      'member'
    )$$,
  'an owner can add an existing Auth account after capacity is raised'
);
select is(
  (
    select can_view_entries
    from public.list_tenant_members(
      'a1111111-1111-4111-8111-111111111111'
    )
    where user_id = '72222222-2222-4222-8222-222222222222'
  ),
  true,
  'new members receive View by default'
);
select is(
  (
    select can_add_entries
    from public.list_tenant_members(
      'a1111111-1111-4111-8111-111111111111'
    )
    where user_id = '72222222-2222-4222-8222-222222222222'
  ),
  false,
  'new members do not receive Add by default'
);
select is(
  (
    select can_edit_entries
    from public.list_tenant_members(
      'a1111111-1111-4111-8111-111111111111'
    )
    where user_id = '72222222-2222-4222-8222-222222222222'
  ),
  false,
  'new members do not receive Edit by default'
);
select is(
  (
    select can_delete_entries
    from public.list_tenant_members(
      'a1111111-1111-4111-8111-111111111111'
    )
    where user_id = '72222222-2222-4222-8222-222222222222'
  ),
  false,
  'new members do not receive Delete by default'
);
select is(
  (
    select active_member_count
    from public.get_tenant_member_capacity(
      'a1111111-1111-4111-8111-111111111111'
    )
  ),
  1,
  'capacity counts member-role memberships only'
);
select lives_ok(
  $$select public.add_tenant_member(
      'a1111111-1111-4111-8111-111111111111',
      'second-member@example.com',
      'member'
    )$$,
  'a second member can be added while capacity remains'
);

select set_config(
  'request.jwt.claim.sub',
  '74444444-4444-4444-8444-444444444444',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "74444444-4444-4444-8444-444444444444",
    "role": "authenticated",
    "session_id": "84444444-4444-4444-8444-444444444444",
    "app_metadata": {}
  }',
  true
);
select throws_ok(
  $$select public.update_tenant_member_role(
      'a1111111-1111-4111-8111-111111111111',
      '75555555-5555-4555-8555-555555555555',
      'member'
    )$$,
  'P0001',
  'MEMBER_LIMIT_REACHED',
  'promoting an owner to member cannot exceed the configured limit'
);
select lives_ok(
  $$select * from public.set_tenant_member_limit(
      'a1111111-1111-4111-8111-111111111111',
      3
    )$$,
  'a Super Admin can raise the limit to permit an owner role transition'
);
select lives_ok(
  $$select public.update_tenant_member_role(
      'a1111111-1111-4111-8111-111111111111',
      '75555555-5555-4555-8555-555555555555',
      'member'
    )$$,
  'a Super Admin can demote an owner when another owner remains'
);
select is(
  (
    select active_member_count
    from public.get_tenant_member_capacity(
      'a1111111-1111-4111-8111-111111111111'
    )
  ),
  3,
  'demoting an owner consumes one member slot'
);
select lives_ok(
  $$select * from public.set_tenant_member_limit(
      'a1111111-1111-4111-8111-111111111111',
      4
    )$$,
  'a Super Admin can raise the limit before promoting the account'
);
select lives_ok(
  $$select public.update_tenant_member_role(
      'a1111111-1111-4111-8111-111111111111',
      '75555555-5555-4555-8555-555555555555',
      'owner'
    )$$,
  'a Super Admin can promote a member to owner'
);
select is(
  (
    select active_member_count
    from public.get_tenant_member_capacity(
      'a1111111-1111-4111-8111-111111111111'
    )
  ),
  2,
  'promoting a member removes that membership from the member count'
);
select lives_ok(
  $$select * from public.set_tenant_member_limit(
      'a1111111-1111-4111-8111-111111111111',
      1
    )$$,
  'a Super Admin can lower the limit below current usage without removing members'
);
select is(
  (
    select remaining_member_count
    from public.get_tenant_member_capacity(
      'a1111111-1111-4111-8111-111111111111'
    )
  ),
  0,
  'over-limit tenants preserve members and report zero remaining capacity'
);

select set_config(
  'request.jwt.claim.sub',
  '71111111-1111-4111-8111-111111111111',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "71111111-1111-4111-8111-111111111111",
    "role": "authenticated",
    "session_id": "81111111-1111-4111-8111-111111111111",
    "app_metadata": {}
  }',
  true
);
select lives_ok(
  $$select public.set_tenant_member_permissions(
      'a1111111-1111-4111-8111-111111111111',
      '72222222-2222-4222-8222-222222222222',
      true,
      false,
      false,
      false
    )$$,
  'the tenant owner can independently update entry permissions'
);
select throws_ok(
  $$select public.set_tenant_member_permissions(
      'a2222222-2222-4222-8222-222222222222',
      '72222222-2222-4222-8222-222222222222',
      true,
      true,
      true,
      true
    )$$,
  '42501',
  null,
  'an owner cannot change permissions in another tenant'
);
select throws_ok(
  $$update public.tenants
    set member_limit = 50
    where id = 'a1111111-1111-4111-8111-111111111111'$$,
  '42501',
  null,
  'tenant owners cannot update member limits directly'
);

select set_config(
  'request.jwt.claim.sub',
  '72222222-2222-4222-8222-222222222222',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "72222222-2222-4222-8222-222222222222",
    "role": "authenticated",
    "session_id": "82222222-2222-4222-8222-222222222222",
    "app_metadata": {}
  }',
  true
);
select ok(
  public.is_tenant_member('a1111111-1111-4111-8111-111111111111'),
  'an active registered tenant member has tenant access'
);
select ok(
  not public.is_tenant_member('a2222222-2222-4222-8222-222222222222'),
  'membership checks do not cross tenant boundaries'
);
select throws_ok(
  $$select * from public.list_tenant_members(
      'a1111111-1111-4111-8111-111111111111'
    )$$,
  '42501',
  null,
  'regular members cannot list tenant accounts'
);
select ok(
  public.can_view_tenant_entries('a1111111-1111-4111-8111-111111111111'),
  'View permission is enforced by the database'
);
select ok(
  not public.can_add_tenant_entries('a1111111-1111-4111-8111-111111111111'),
  'View-only members cannot add entries'
);
select ok(
  not public.can_edit_tenant_entries('a1111111-1111-4111-8111-111111111111'),
  'View-only members cannot edit entries'
);
select ok(
  not public.can_delete_tenant_entries('a1111111-1111-4111-8111-111111111111'),
  'View-only members cannot delete entries'
);
select is(
  (select count(*) from public.parking_sessions),
  1::bigint,
  'member reads are tenant-isolated'
);
select is(
  (
    select count(*)
    from public.parking_sessions
    where tenant_id = 'a2222222-2222-4222-8222-222222222222'
  ),
  0::bigint,
  'a member cannot read another tenant parking entry'
);
select throws_ok(
  $$insert into public.parking_sessions (
      tenant_id,
      plate_number,
      entry_time,
      allowed_duration_value,
      allowed_duration_unit,
      expires_at,
      created_by
    )
    values (
      'a1111111-1111-4111-8111-111111111111',
      'VIEW-ONLY-ADD',
      now(),
      1,
      'hours',
      now() + interval '1 hour',
      '72222222-2222-4222-8222-222222222222'
    )$$,
  '42501',
  null,
  'a View-only member cannot insert through the table API'
);
select is(
  (
    with updated as (
      update public.parking_sessions
      set plate_number = 'VIEW-ONLY-EDIT'
      where id = 'c1111111-1111-4111-8111-111111111111'
      returning id
    )
    select count(*) from updated
  ),
  0::bigint,
  'a View-only member cannot edit through the table API'
);
select is(
  (
    with deleted as (
      delete from public.parking_sessions
      where id = 'c1111111-1111-4111-8111-111111111111'
      returning id
    )
    select count(*) from deleted
  ),
  0::bigint,
  'a View-only member cannot delete through the table API'
);
select throws_ok(
  $$select public.set_tenant_member_permissions(
      'a1111111-1111-4111-8111-111111111111',
      '72222222-2222-4222-8222-222222222222',
      true,
      true,
      true,
      true
    )$$,
  '42501',
  null,
  'a member cannot grant their own entry permissions'
);
select throws_ok(
  $$update public.tenant_memberships
    set can_add_entries = true
    where tenant_id = 'a1111111-1111-4111-8111-111111111111'
      and user_id = '72222222-2222-4222-8222-222222222222'$$,
  '42501',
  null,
  'members cannot update their permission columns directly'
);

select set_config(
  'request.jwt.claim.sub',
  '71111111-1111-4111-8111-111111111111',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "71111111-1111-4111-8111-111111111111",
    "role": "authenticated",
    "session_id": "81111111-1111-4111-8111-111111111111",
    "app_metadata": {}
  }',
  true
);
select lives_ok(
  $$select public.set_tenant_member_permissions(
      'a1111111-1111-4111-8111-111111111111',
      '72222222-2222-4222-8222-222222222222',
      false,
      true,
      false,
      false
    )$$,
  'the owner can grant Add without granting View'
);

select set_config(
  'request.jwt.claim.sub',
  '72222222-2222-4222-8222-222222222222',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "72222222-2222-4222-8222-222222222222",
    "role": "authenticated",
    "session_id": "82222222-2222-4222-8222-222222222222",
    "app_metadata": {}
  }',
  true
);
select ok(
  not public.can_view_tenant_entries('a1111111-1111-4111-8111-111111111111')
    and public.can_add_tenant_entries('a1111111-1111-4111-8111-111111111111')
    and not public.can_edit_tenant_entries('a1111111-1111-4111-8111-111111111111')
    and not public.can_delete_tenant_entries('a1111111-1111-4111-8111-111111111111'),
  'Add-only remains independent from View, Edit, and Delete'
);
select is(
  (select count(*) from public.parking_sessions),
  0::bigint,
  'Add-only members cannot browse existing entries'
);
select set_config(
  'test.member_photo_session_id',
  public.create_parking_session(
    'a1111111-1111-4111-8111-111111111111',
    'MEMBER-PHOTO-ADD',
    now(),
    1,
    'hours',
    now() + interval '1 hour',
    0,
    0,
    true
  )::text,
  true
);
select set_config(
  'test.member_photo_path',
  auth.uid()::text || '/'
    || current_setting('test.member_photo_session_id')
    || '/vehicle_photo.jpg',
  true
);
select lives_ok(
  $$select public.set_new_parking_session_photo_path(
      current_setting('test.member_photo_session_id')::uuid,
      current_setting('test.member_photo_path')
    )$$,
  'Add-only members can link their own pending photo'
);
select ok(
  public.can_upload_vehicle_photo(current_setting('test.member_photo_path')),
  'Add-only members can upload only their pending photo'
);
select ok(
  not public.can_read_vehicle_photo(current_setting('test.member_photo_path')),
  'Add permission does not grant photo read access'
);
select lives_ok(
  $$select public.complete_parking_session_photo_upload(
      current_setting('test.member_photo_session_id')::uuid
    )$$,
  'Add-only members can complete their photo upload'
);
select ok(
  not public.can_upload_vehicle_photo(current_setting('test.member_photo_path')),
  'completed uploads no longer use the pending-upload exception'
);

select set_config(
  'request.jwt.claim.sub',
  '71111111-1111-4111-8111-111111111111',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "71111111-1111-4111-8111-111111111111",
    "role": "authenticated",
    "session_id": "81111111-1111-4111-8111-111111111111",
    "app_metadata": {}
  }',
  true
);
select lives_ok(
  $$select public.set_tenant_member_permissions(
      'a1111111-1111-4111-8111-111111111111',
      '72222222-2222-4222-8222-222222222222',
      false,
      false,
      true,
      false
    )$$,
  'the owner can grant Edit without View, Add, or Delete'
);

select set_config(
  'request.jwt.claim.sub',
  '72222222-2222-4222-8222-222222222222',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "72222222-2222-4222-8222-222222222222",
    "role": "authenticated",
    "session_id": "82222222-2222-4222-8222-222222222222",
    "app_metadata": {}
  }',
  true
);
select ok(
  not public.can_view_tenant_entries('a1111111-1111-4111-8111-111111111111')
    and not public.can_add_tenant_entries('a1111111-1111-4111-8111-111111111111')
    and public.can_edit_tenant_entries('a1111111-1111-4111-8111-111111111111')
    and not public.can_delete_tenant_entries('a1111111-1111-4111-8111-111111111111'),
  'Edit-only remains independent from View, Add, and Delete'
);
select is(
  (
    with updated as (
      update public.parking_sessions
      set plate_number = 'EDITED-WITHOUT-VIEW'
      where id = 'c1111111-1111-4111-8111-111111111111'
      returning id
    )
    select count(*) from updated
  ),
  1::bigint,
  'Edit-only members can edit a known entry without browse access'
);
select ok(
  public.can_update_vehicle_photo(current_setting('test.member_photo_path'))
    and not public.can_read_vehicle_photo(
      current_setting('test.member_photo_path')
    ),
  'Edit permits updating the linked photo without granting photo reads'
);

select set_config(
  'request.jwt.claim.sub',
  '71111111-1111-4111-8111-111111111111',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "71111111-1111-4111-8111-111111111111",
    "role": "authenticated",
    "session_id": "81111111-1111-4111-8111-111111111111",
    "app_metadata": {}
  }',
  true
);
select lives_ok(
  $$select public.set_tenant_member_permissions(
      'a1111111-1111-4111-8111-111111111111',
      '72222222-2222-4222-8222-222222222222',
      false,
      false,
      false,
      true
    )$$,
  'the owner can grant Delete without View, Add, or Edit'
);

select set_config(
  'request.jwt.claim.sub',
  '72222222-2222-4222-8222-222222222222',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "72222222-2222-4222-8222-222222222222",
    "role": "authenticated",
    "session_id": "82222222-2222-4222-8222-222222222222",
    "app_metadata": {}
  }',
  true
);
select ok(
  not public.can_view_tenant_entries('a1111111-1111-4111-8111-111111111111')
    and not public.can_add_tenant_entries('a1111111-1111-4111-8111-111111111111')
    and not public.can_edit_tenant_entries('a1111111-1111-4111-8111-111111111111')
    and public.can_delete_tenant_entries('a1111111-1111-4111-8111-111111111111'),
  'Delete-only remains independent from View, Add, and Edit'
);
select ok(
  public.can_delete_vehicle_photo(current_setting('test.member_photo_path'))
    and not public.can_update_vehicle_photo(
      current_setting('test.member_photo_path')
    ),
  'Delete permission does not grant photo update access'
);
select is(
  (
    with deleted as (
      delete from public.parking_sessions
      where id = current_setting('test.member_photo_session_id')::uuid
      returning id
    )
    select count(*) from deleted
  ),
  1::bigint,
  'Delete-only members can delete a known entry without browse access'
);

select set_config(
  'request.jwt.claim.sub',
  '74444444-4444-4444-8444-444444444444',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "74444444-4444-4444-8444-444444444444",
    "role": "authenticated",
    "session_id": "84444444-4444-4444-8444-444444444444",
    "app_metadata": {}
  }',
  true
);
select is(
  (
    select plate_number
    from public.parking_sessions
    where id = 'c1111111-1111-4111-8111-111111111111'
  ),
  'EDITED-WITHOUT-VIEW',
  'Super Admins can inspect entries changed by an authorized member'
);
select is(
  (
    select count(*)
    from public.parking_sessions
    where id = current_setting('test.member_photo_session_id')::uuid
  ),
  0::bigint,
  'Delete-only removal is persisted'
);

select set_config(
  'request.jwt.claim.sub',
  '71111111-1111-4111-8111-111111111111',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "71111111-1111-4111-8111-111111111111",
    "role": "authenticated",
    "session_id": "81111111-1111-4111-8111-111111111111",
    "app_metadata": {}
  }',
  true
);
select ok(
  exists (
    select 1
    from public.list_tenant_member_audit_events(
      'a1111111-1111-4111-8111-111111111111',
      100
    )
    where action = 'member_added'
  ),
  'tenant owners can inspect member-management audit events'
);
select lives_ok(
  $$select public.remove_tenant_member(
      'a1111111-1111-4111-8111-111111111111',
      '72222222-2222-4222-8222-222222222222'
    )$$,
  'tenant owners can remove a member from their own tenant'
);
select is(
  (
    select active_member_count
    from public.get_tenant_member_capacity(
      'a1111111-1111-4111-8111-111111111111'
    )
  ),
  1,
  'removing a member frees its member slot'
);
select lives_ok(
  $$select public.remove_tenant_member(
      'a1111111-1111-4111-8111-111111111111',
      '73333333-3333-4333-8333-333333333333'
    )$$,
  'tenant owners can remove a second member without deleting its Auth identity'
);
select is(
  (
    select remaining_member_count
    from public.get_tenant_member_capacity(
      'a1111111-1111-4111-8111-111111111111'
    )
  ),
  1,
  'removing all members restores the single default slot'
);
reset role;
select is(
  (
    select count(*)
    from auth.users
    where id = '72222222-2222-4222-8222-222222222222'
  ),
  1::bigint,
  'removing a tenant membership preserves the shared Auth identity'
);
select is(
  (
    select status
    from public.device_sessions
    where tenant_id = 'a1111111-1111-4111-8111-111111111111'
      and user_id = '72222222-2222-4222-8222-222222222222'
      and auth_session_id = '82222222-2222-4222-8222-222222222222'
  ),
  'revoked',
  'removing a member revokes their registered tenant device session'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '72222222-2222-4222-8222-222222222222',
  true
);
select set_config(
  'request.jwt.claims',
  '{
    "sub": "72222222-2222-4222-8222-222222222222",
    "role": "authenticated",
    "session_id": "82222222-2222-4222-8222-222222222222",
    "app_metadata": {}
  }',
  true
);
select ok(
  not public.is_tenant_member('a1111111-1111-4111-8111-111111111111'),
  'removing a member revokes their tenant access'
);

select * from finish();
rollback;
