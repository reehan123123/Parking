# Supabase setup

This document describes how to configure and verify the Parking Management
PWA's Supabase project without placing privileged credentials in the Flutter
client.

## 1. Create or select the project

1. Create or select the Supabase project that will host the application.
2. In **Project Settings > API**, copy the project URL and publishable key
   (called the anon key in older projects).
3. Keep the service-role key private. It is not required by the Flutter client
   and must never be placed in Dart code, browser configuration, Git, or logs.
4. In **Authentication > Providers**, enable Email. Keep public sign-ups
   disabled for this private application.

The Flutter app reads the two public values through compile-time defines:

```powershell
$env:SUPABASE_URL = "https://your-project-ref.supabase.co"
$env:SUPABASE_PUBLISHABLE_KEY = "sb_publishable_replace_me"

flutter run -d chrome `
  --dart-define=SUPABASE_URL=$env:SUPABASE_URL `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=$env:SUPABASE_PUBLISHABLE_KEY
```

PowerShell expands the values before Flutter embeds them. Do not record real
values in shared logs or commit them. Production builds use the same two
public values from GitHub settings; no Supabase secret/service-role key is
needed by the build workflow.

## 2. Apply the migrations

The migrations are applied in timestamp order:

```text
supabase/migrations/20261014160000_create_parking_sessions_security.sql
supabase/migrations/20261018185121_tenant_administration.sql
```

The first migration creates the initial `parking_sessions` table, private
`vehicle-photos` bucket, and owner-only policies. The tenant-administration
migration:

- Creates `public.tenants`, `public.tenant_memberships`, and the
  database-backed `public.super_admins` table.
- Creates a `Personal workspace` and owner membership for every existing
  Auth user, then backfills that user's parking sessions without changing
  ownership, duration, or photo paths.
- Adds `tenant_id` to every parking session and replaces owner-only policies
  with tenant-membership and Super Admin RLS.
- Keeps vehicle photos private and authorizes access through the related
  session's tenant membership or the Super Admin role.
- Adds `public.create_tenant`, which checks the caller's database-backed role
  and atomically assigns an existing Auth account as the new tenant owner.

The tenant migration has not been applied to the hosted project. Review it
and get explicit approval before applying it to production. It preserves
existing parking rows but changes their authorization boundary.

### Supabase CLI path

Install the Supabase CLI using the official instructions, authenticate, and
link this directory to the intended project:

```powershell
supabase login
supabase link --project-ref your-project-ref
supabase db push
```

The CLI and Docker were unavailable in the development environment, so these
commands have not been executed here. Do not treat a successful Flutter build
as proof that the migration reached Supabase.

Use one migration-application path per environment. If a migration was
applied manually in the SQL Editor, reconcile Supabase's migration history
before using `supabase db push`; do not blindly apply the same file again.

### SQL Editor path

If the initial parking migration is already applied, review and run only
`20261018185121_tenant_administration.sql` exactly once. Do not rerun the
initial migration. Confirm that the bucket remains private and RLS is enabled:

```sql
select id, name, public
from storage.buckets
where id = 'vehicle-photos';

select relrowsecurity
from pg_class
where oid = 'public.parking_sessions'::regclass;

select relrowsecurity
from pg_class
where oid = 'public.tenant_memberships'::regclass;
```

The bucket must show `public = false`, and both table checks must show
`relrowsecurity = true`.

## 3. Provision the initial Super Admin

1. In **Authentication > Users**, create or verify the private
   `dieselpetrol6@gmail.com` account.
2. Apply the tenant-administration migration.
3. Review and run
   `supabase/operations/provision_initial_super_admin.sql` in the SQL Editor.
   This operation grants the application Super Admin role only; it does not
   create or change the Auth account.
4. Sign in to the app. The Admin destination is shown only when the database
   recognizes the role.

If the account does not exist, the SQL operation stops without granting the
role. The provisioning script has not been run against the hosted project.
Authenticated users cannot read or write `public.super_admins` directly.

## 4. Create tenant workspaces

Only a Super Admin can use the app's **Admin > Create tenant** form. Enter a
tenant name and the email address of an account that already exists in
Supabase Authentication. The database function validates the role and
atomically creates the workspace and owner membership.

The app does not create Auth users, send invitations, or use a service-role
key. Create or invite an owner through the intended Supabase Auth process
first, then create the tenant in the app. Tenant `owner` and `member` roles
currently share the same parking-session access; granular member-management
permissions are not implemented.

## 5. Test the policies

The source-controlled database tests are:

```text
supabase/tests/parking_sessions_rls.test.sql
supabase/tests/vehicle_photos_rls.test.sql
```

With the Supabase CLI and Docker available, run them against a local or
non-production project:

```powershell
supabase test db
```

The tests cover anonymous denial, tenant-scoped reads and writes,
cross-tenant transfer denial, prevention of client-side Super Admin grants,
Super Admin access, tenant-creation authorization, and private Storage policy
definitions. They have not been executed in this environment. Hosted RLS and
photo access still require a safe project and separate test accounts.

## 6. Authentication URLs and troubleshooting

After the Cloudflare Pages URL is known, set that exact HTTPS origin as the
Supabase Auth Site URL and add only required redirect URLs. Keep local
development URLs separate.

- A build without `SUPABASE_URL` or `SUPABASE_PUBLISHABLE_KEY` intentionally
  shows **Supabase configuration required**.
- A successful sign-in before the tenant migration is not sufficient; the
  current client displays a setup error rather than bypassing tenant
  authorization.
- **No workspace assigned** means the account has no `tenant_memberships`
  row. The migration creates workspaces for existing Auth users; a new owner
  must be assigned to a tenant by a Super Admin.
- The parking-entry flow inserts the tenant-owned session row before photo
  upload to
  `{created-by-user-id}/{parking-session-id}/{filename}`. On upload failure,
  it removes the Storage object before deleting the row. If cleanup fails,
  the row is retained and the form exposes a retry action.
- Photo input supports JPEG/PNG/WebP, uses the on-demand `camera` package,
  and rejects images larger than 10 MB. Camera access depends on localhost or
  HTTPS, browser support, and user permissions; file selection remains the
  fallback.
