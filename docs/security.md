# Security model and verification

The application uses Supabase Auth, PostgreSQL row-level security (RLS), and
private Storage. Tenant isolation and the global Super Admin role are
enforced by the database, not by Flutter navigation or client-supplied IDs.

## Client boundary

The Flutter Web bundle contains only the Supabase project URL and public
publishable/anon key. Those values identify a public client; they do not
replace authorization. Never expose a service-role key, database password,
JWT signing secret, or other privileged credential in Dart code, browser
configuration, Git, generated assets, or logs.

The app validates compile-time configuration before initializing Supabase.
Missing configuration produces an explicit setup page instead of an
unauthenticated fallback.

## Local-only development mode

The opt-in `PARKING_BACKEND=local` mode uses a separate API bound to
`127.0.0.1` and the local `parking_local` database. Database credentials and
the signing secret remain in the ignored `local-api\.env.local-api` file; the
browser receives only an opaque local access token. Local photos are stored
under the ignored `local-api\storage\` directory.

This development API is not a Supabase emulator and does not use Supabase RLS
or hosted Storage policies. It must not be exposed outside the loopback
interface, deployed, or used with production data. Production/default builds
remain on the Supabase Auth, RLS, and private Storage model described below.

## Authentication and role assignment

The UI supports email/password sign-in and sign-out. Public self-registration
is not implemented. A Super Admin can create a new tenant-owner account
through the authenticated `create-tenant-owner` Edge Function. Existing Auth
accounts are assigned without changing their credentials. A new account is
email-confirmed by this private administrative flow and receives a
cryptographically random temporary password shown only in the Super Admin
dialog; the password is not persisted or logged by the application.

New owner accounts receive a server-set `app_metadata` flag requiring a
password change. `AuthGate` routes them to the password-change screen, while
`is_super_admin()` and `is_tenant_member()` deny tenant, parking-session, and
private-photo access until the change is completed by the
`complete-temporary-password-reset` Edge Function. The client cannot set or
clear the flag. The functions validate the caller's JWT and database-backed
Super Admin role where required; privileged Auth Admin access remains
server-side.

`public.super_admins` is database-backed and has no authenticated-client
table privileges or user-facing insert path. The `is_super_admin()` function
returns the current user's role for RLS and tenant loading. A reviewed
one-time SQL operation at
`supabase/operations/provision_initial_super_admin.sql` assigns
`dieselpetrol6@gmail.com` after that Auth account and the tenant migration
exist. That operation has not been run against the hosted project.

The application Super Admin can view and manage parking records and private
photos across tenants, create parking entries for an active tenant, and create
or manage tenant workspaces and memberships. This is not access to Supabase
project settings, passwords, or service-role credentials.

## Tenant and database authorization

`public.tenants` identifies parking workspaces.
`public.tenant_memberships` maps Auth users to workspaces with `owner` or
`member` role. A Super Admin can add or remove existing Auth users and change
their tenant role. Both roles currently have the same parking-session
permissions.

The tenant migration creates a `Personal workspace` and owner membership for
each existing Auth user, then assigns that user's existing parking sessions
to it. It preserves `created_by`, timestamps, expiry values, and photo paths.
The tenant-administration migration adds the database-backed role and
tenant-scoped access model. The tenant-management migration adds a reversible
`archived_at` lifecycle and Super Admin-only operations to rename, archive,
restore, and manage tenant memberships. Archiving retains all parking rows and
photo objects while `is_tenant_member()` denies access to tenant members;
Super Admins retain access for support and restoration. Membership procedures
prevent removing or demoting the last owner. Hosted migration and
provisioning status must be verified separately.

`public.parking_sessions` retains `created_by` for audit and photo path
compatibility and has a required `tenant_id`. RLS enforces:

- Select, update, and delete are allowed only for a member of the row's
  tenant or a database-recognized Super Admin.
- Inserts must use the caller's Auth user ID as `created_by` and a tenant the
  caller belongs to, unless the caller is a Super Admin.
- Non-admin users cannot change a session's `tenant_id` or `created_by`.
- Authenticated users cannot insert or update rows in `public.super_admins`.
- Tenant creation is restricted to Super Admins. The authenticated
  `create-tenant-owner` Edge Function provisions a missing Auth user
  server-side, then calls the idempotent `create_tenant_for_request` RPC to
  assign the owner in the same transaction as tenant creation. Existing users
  keep their current passwords.
- Tenant-creation request IDs make retries idempotent. If Auth account
  creation succeeds but tenant setup cannot be confirmed, the UI preserves
  the temporary password and allows a retry without silently claiming the
  tenant was created.
- Tenant rename, archive/restore, and membership changes are performed through
  Super Admin-only security-definer functions; authenticated clients have no
  direct tenant or membership write grants.

The Flutter repository sends an explicit selected-tenant filter for list and
summary queries. A global Super Admin view omits that filter; RLS still
enforces the caller's real role in both cases. Direct-ID lookups and mutations
also rely on RLS rather than trusting client-side ownership filters.

## Private vehicle-photo authorization

The `vehicle-photos` bucket remains private. The object path remains:

```text
{session-created-by-user-id}/{parking-session-id}/{filename}
```

Each Storage operation verifies that the second path component identifies a
parking session, that the first component matches that row's `created_by`,
and that the current user is a member of the session tenant or a Super Admin.
This preserves existing object paths while granting access at the tenant
boundary. Signed URLs are created only after the associated session and photo
path are verified through the authenticated client.

The save sequence remains row first, Storage upload second, with cleanup on
failure. Photo deletion precedes session deletion; cleanup failures remain
visible and retryable. Lists do not download photo bytes.

## Verification

Run the local Flutter checks:

```powershell
dart format .
flutter analyze
flutter test
flutter build web --release
git diff --check
```

The source-controlled database tests are
`supabase/tests/parking_sessions_rls.test.sql` and
`supabase/tests/vehicle_photos_rls.test.sql`,
`supabase/tests/tenant_management.test.sql`, and
`supabase/tests/tenant_owner_onboarding.test.sql`. Run them with Supabase CLI
and Docker against a local or non-production project:

```powershell
supabase test db
```

The SQL tests have not been executed in this environment. Hosted RLS, two-user
tenant isolation, private-photo access, live Super Admin provisioning, and
production migration state remain unverified.

Inspect for privileged credential patterns:

```powershell
rg -n -i "service[-_ ]?role|sb_secret|jwt secret|database password" `
  lib web build README.md docs supabase
```

Documentation references and placeholder variable names are expected; no real
privileged values may appear in source, release assets, or logs.
