# Supabase setup

This document describes how to configure and verify the Parking Management
PWA's Supabase project without placing privileged credentials in the Flutter
client.

Supabase remains the production/default backend. For a single local database
without Docker, Supabase CLI, or a hosted development project, use
[Local PostgreSQL development](local-development.md); that mode is isolated
from hosted Supabase and does not apply its migrations.

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
supabase/migrations/20261019090000_tenant_management.sql
supabase/migrations/20261020090000_tenant_owner_onboarding.sql
supabase/migrations/20261021090000_parking_session_charges.sql
supabase/migrations/20261021110000_password_reset_rate_limit.sql
supabase/migrations/20261022090000_tenant_activation_expiry_contact.sql
supabase/migrations/20261023090000_fix_list_tenant_members_email_type.sql
supabase/migrations/20261024090000_device_session_limits.sql
supabase/migrations/20261024100000_tenant_member_limits_permissions.sql
supabase/migrations/20261024110000_fix_device_session_email_return_types.sql
supabase/migrations/20261025120000_parking_push_notifications.sql
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
- The tenant-management migration adds reversible tenant archiving, tenant
  renaming, and Super Admin member-management procedures. Archiving retains
  parking records and photos while suspending tenant-member access.
- The tenant-owner-onboarding migration adds an idempotent tenant-creation
  wrapper, a service-role-only Auth account lookup, and a database access gate
  for accounts that must change a temporary password.
- The parking-charge migration adds tenant-scoped charge fields and database
  validation; the password-reset migration adds a service-role-only email
  attempt counter.
- The tenant lifecycle migration adds validity dates and contact fields. The
  later member-email fix preserves member listing compatibility.
- The device-session migration adds inherited platform/tenant/account limits,
  an atomic session registry, tenant RLS gating, a refresh hook, revocation
  RPCs, and audit events. It does not create session records for existing
  Auth sessions.
- The tenant-member migration adds a stored member cap, safe permission
  defaults/backfill, tenant-scoped member and policy audit records,
  transactional capacity checks, owner-scoped management RPCs, and
  action-specific parking and photo authorization. The default is one member
  per tenant, excluding owners; the configurable maximum is 50.
- The device-session follow-up migration casts Auth email values to `text` in
  three table-returning RPCs whose declared result types previously disagreed
  with `auth.users.email`.
- The parking-notification migration adds private per-user Web Push
  subscriptions, once-only 90%-duration and expiry events for unpaid parking
  sessions, an edit-authorized full-payment RPC, and a `pg_cron` dispatcher
  using `pg_net` and Vault. This migration is pending review and has not been
  applied to the hosted project.

The tenant-administration and tenant-management migrations must be reviewed
and applied in order. They preserve existing parking rows but change their
authorization boundary. Hosted migration and role-provisioning status must be
verified before expecting the Admin features to work.

### Supabase CLI path

Install the Supabase CLI using the official instructions, authenticate, and
link this directory to the intended project:

```powershell
supabase login
supabase link --project-ref your-project-ref
supabase db push
```

The Supabase CLI is available in this development environment, but Docker and
a local Supabase database are unavailable. The verified `parking-management`
project has migrations applied through
`20261024110000_fix_device_session_email_return_types.sql`; linked migration
history is in sync. Post-application
`supabase db lint --linked --schema public` passed with “No schema errors
found.” No migration has been applied to a local Supabase database. Do not
treat a successful Flutter build as proof that a migration reached Supabase.

After applying all migrations, deploy the authenticated Edge Functions:

```powershell
supabase functions deploy create-tenant-owner
supabase functions deploy create-tenant-member
supabase functions deploy complete-temporary-password-reset
```

Both functions keep JWT verification enabled. Supabase injects the project
URL and API-key dictionaries into the Edge Function runtime; the privileged
secret key is used only server-side. Do not put it in Flutter configuration,
GitHub build settings, browser assets, or function responses.

The parking-notification dispatcher is a separate Edge Function protected by
a high-entropy cron secret rather than JWT authentication. Before enabling its
database scheduler, configure the Edge Function secrets
`PARKING_VAPID_PUBLIC_KEY`, `PARKING_VAPID_PRIVATE_KEY`,
`PARKING_VAPID_SUBJECT`, and `PARKING_NOTIFICATION_CRON_SECRET`. Keep the
private VAPID key and cron secret server-side. Store matching
`parking_notifications_project_url` and
`parking_notifications_cron_secret` values in Supabase Vault; the migration
does not contain secret values. Build the browser with only the public VAPID
key in the `PARKING_PUSH_VAPID_PUBLIC_KEY` define. See
[opt-in parking Web Push](security.md#opt-in-parking-web-push) for setup and
safety requirements.

Deploy the dispatcher only after reviewing and applying the migration in the
intended non-production environment:

```powershell
supabase functions deploy dispatch-parking-notifications --no-verify-jwt
```

Use one migration-application path per environment. If a migration was
applied manually in the SQL Editor, reconcile Supabase's migration history
before using `supabase db push`; do not blindly apply the same file again.

### SQL Editor path

If the initial parking migration is already applied, review and run
`20261018185121_tenant_administration.sql` exactly once, followed by
`20261019090000_tenant_management.sql` and
`20261020090000_tenant_owner_onboarding.sql`, each exactly once. Do not rerun
the initial migration. Then run
`supabase/operations/provision_initial_super_admin.sql`. Confirm that the
bucket remains private and RLS is enabled:

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
role. The provisioning script's current hosted status was not verified during
the 2026-10-24 rollout. Authenticated users cannot read or write
`public.super_admins` directly.

## 4. Create tenant workspaces

Only a Super Admin can use the Admin screen to create, rename, archive, and
restore tenants, manage member limits, or manage memberships across tenants.
Tenant owners can manage member-role accounts only in their own tenant. New
members default to View-only, while existing memberships retain their prior
access. Existing Supabase accounts are assigned without changing credentials.
If an email is not registered, `create-tenant-member` creates an Auth user
server-side, marks its email confirmed without a separate ownership check,
adds membership only to the selected tenant, and returns a cryptographically
random temporary password once. The manager must share it securely, and the
member must change it at first sign-in before any tenant or parking data is
accessible.

For tenant owners, the Flutter app calls the authenticated member Edge
Function; it never creates Auth users directly or receives the privileged API
key. Archiving preserves parking records and photos and can be reversed;
removing a membership does not delete the Auth account or parking data and
revokes the member's device sessions for that tenant. A tenant must always
retain at least one owner. Member capacity counts member-role membership rows
only, excluding owners. See
[tenant member management](tenant-member-management.md) for the limits,
permissions, and local-only validation procedure.

## 5. Test the policies

The source-controlled database tests are:

```text
supabase/tests/parking_sessions_rls.test.sql
supabase/tests/vehicle_photos_rls.test.sql
supabase/tests/tenant_management.test.sql
supabase/tests/tenant_owner_onboarding.test.sql
supabase/tests/device_session_limits.test.sql
supabase/tests/tenant_member_limits_permissions.test.sql
supabase/tests/parking_push_notifications.test.sql
```

With Docker available, run them only against the local Supabase database:

```powershell
supabase test db --local
```

The tests cover anonymous denial, tenant-scoped reads and writes,
cross-tenant transfer denial, prevention of client-side Super Admin grants,
Super Admin access, tenant creation and management, archive/restore behavior,
owner retention, temporary-password RLS denial, request idempotency, and
private Storage policy definitions. The tenant-member test also covers
capacity, role transitions, member permissions, tenant isolation, audit
visibility, and the pending-photo lifecycle. They have not been executed in
this environment. Hosted RLS and photo access still require a safe project
and separate test accounts.

The device-session feature also has a two-connection PostgreSQL race test.
See [device-session limits](device-session-limits.md) for the loopback-only
test command, migration dry-run, hook configuration, and deployment boundary.
The tenant-member migration includes a separate loopback-only two-connection
capacity race test documented in
[tenant member management](tenant-member-management.md). Both database tests
are skipped unless explicitly configured with a local Supabase database URL.

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
