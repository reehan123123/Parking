begin;

select plan(5);

select is(
  (select public from storage.buckets where id = 'vehicle-photos'),
  false,
  'vehicle photo bucket is private'
);

select ok(
  exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Tenant members and Super Admins can read vehicle photos'
  ),
  'vehicle photo select policy exists'
);

select ok(
  exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Tenant members and Super Admins can upload vehicle photos'
  ),
  'vehicle photo insert policy exists'
);

select ok(
  exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Tenant members and Super Admins can update vehicle photos'
  ),
  'vehicle photo update policy exists'
);

select ok(
  exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Tenant members and Super Admins can delete vehicle photos'
  ),
  'vehicle photo delete policy exists'
);

select * from finish();
rollback;
