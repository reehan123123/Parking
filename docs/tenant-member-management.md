# Tenant member management

This feature extends the existing `public.tenants` and
`public.tenant_memberships` model. It does not add a second user, tenant, or
device registry. An existing Supabase Auth account can be assigned to a
tenant without changing its password or other memberships. If the email is
not registered, the authenticated `create-tenant-member` Edge Function
creates a new account and adds only the requested tenant membership. It
marks the email confirmed without a separate ownership check and returns a
one-time temporary password to the authorized manager for secure sharing. The
account must change that password before accessing tenant data. No new profile
fields or invitation system are introduced.

## Capacity policy

- `public.tenants.member_limit` is stored in PostgreSQL and defaults to one
  member, excluding all tenant owners. The allowed range is 1 through 50.
- Capacity is the count of current `role = 'member'` membership rows.
  Invitations and soft-deleted memberships are not supported.
- Existing tenants receive the default limit without removing memberships.
  If an existing tenant already has more members than its limit, those
  memberships are preserved and further additions are rejected until the
  count is below the configured limit. A newly provisioned member is added
  inside this same capacity-enforced membership flow and consumes a slot.
- `add_tenant_member` locks the tenant row before checking and inserting a
  member. Owner-to-member role transitions use the same lock and capacity
  check. The stable capacity error is `MEMBER_LIMIT_REACHED`; the database
  also includes the configured limit, current count, and remaining count.
- The Super Admin can set a tenant limit. Owners can view usage but cannot
  change the limit. Authenticated clients cannot write `member_limit`
  directly.
- Removing a membership frees a slot, revokes the member's registered device
  sessions for that tenant, and preserves the shared Auth account, parking
  records, and audit history.

## Roles and entry permissions

Owners retain full tenant entry access and manage only member-role accounts
in their own tenant. They can add an existing Auth account or provision a new
login by email, update its four independent permissions, and remove its
membership. They cannot change tenant limits, manage another tenant, promote
an account to owner, or remove an owner. Super Admins retain platform-wide
member, role, and limit management.

New member rows default to **View enabled** and **Add/Edit/Delete disabled**.
The migration backfills existing memberships with all four permissions
enabled to preserve their prior tenant-wide access. An owner membership
continues to receive full permissions regardless of the stored flags.

The permissions are enforced by database functions and RLS, not just Flutter
controls:

| Permission | Effect |
| --- | --- |
| View | Read parking entries and associated private photos for that tenant. |
| Add | Create entries and complete the pending-photo upload flow for entries the member created. |
| Edit | Update entries and linked photos in the tenant. |
| Delete | Delete entries and linked photos in the tenant. |

Permissions do not imply one another. For example, an Edit-only member can
update a known entry ID but cannot list or read its details. The app hides
unavailable actions and provides an Add-only path when View is disabled;
PostgreSQL RLS remains authoritative for direct API calls and stale clients.
All checks also retain tenant isolation and the active device-session gate.

Private photo objects retain the path
`{created-by-user-id}/{parking-session-id}/{filename}`. Storage policies
verify the path against the associated session and its exact recorded photo
path. Add-only upload access is limited to the creator's pending photo flow;
after upload completion that exception closes. View, Edit, and Delete are
checked separately for subsequent reads and mutations.

## User interface

- Tenant owners see **Manage Members** in Settings; regular members do not.
- The member screen reports usage as `active / allowed`, shows remaining
  capacity, and hides **Add Member** when no slot remains.
- Existing accounts keep their current credentials. A newly created account
  receives a cryptographically random temporary password in a one-time
  dialog, is assigned only to the selected tenant, and must change its
  password before tenant access. The password is not stored in application
  data or logs.
- The Super Admin tenant manager displays member usage and can change the
  tenant limit. Its device-policy entry reuses the existing device-session
  administration flow instead of introducing duplicate policy state.
- Member records show the existing email, role, creation metadata, and
  permission flags. No name or mobile field is invented.
- Removal requires confirmation. It removes only the tenant membership, not
  the Auth identity or parking history.

## Local validation

These commands target only a local Supabase database. `supabase db reset`
drops and recreates that local database; do not run it against a linked or
hosted project. The checked-in Auth Send Email hook configuration also
requires a well-formed secret for the CLI to parse. For SQL-only local tests,
generate a disposable value in the current PowerShell process:

```powershell
$bytes = [System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32)
$env:SEND_EMAIL_HOOK_SECRET = 'v1,whsec_' + [Convert]::ToBase64String($bytes)
supabase start
supabase db push --dry-run --local
supabase db reset
supabase test db --local
Remove-Item Env:\SEND_EMAIL_HOOK_SECRET
```

The generated value is not a production secret and is not persisted. The
checked-in hook URI points to the hosted email function, so do not exercise
local Auth email flows while using this SQL-test setup.

The member-limit concurrency test opens two independent connections and
accepts only PostgreSQL at the local Supabase endpoint
(`postgres@127.0.0.1:54322/postgres`, including localhost/IPv6 loopback
aliases). Set its connection string locally using the local Supabase database
password; do not paste the value into logs:

```powershell
$env:TENANT_MEMBER_TEST_DATABASE_URL = "postgresql://postgres:<local-db-password>@127.0.0.1:54322/postgres"
npm --prefix local-api run test:tenant-member-concurrency
Remove-Item Env:\TENANT_MEMBER_TEST_DATABASE_URL
```

The local API mirrors the member limit and permissions in its isolated
development schema. It can create a local-only account in the same database
transaction, returns its temporary password once, and uses a request ledger to
recover safely from retries. The local API has no email service; this
development-only flow must not be exposed outside loopback or used with
production data. Before upgrading an existing `parking_local` database,
apply `local-api/migrations/003_tenant_member_limits_permissions.sql` and
then `local-api/migrations/004_tenant_member_account_provisioning.sql` with
the local database owner using the migration commands in
[local development](local-development.md). The runtime `parking_api` role
cannot alter schema. Then run its integration suite only against
`parking_local`:

```powershell
npm --prefix local-api test
npm --prefix local-api run test:local-api
```

Flutter validation from the repository root:

```powershell
dart format .
flutter analyze
flutter test
flutter build web --release
git diff --check
```

No hosted migration, production data change, Auth Hook update, commit, push,
or deployment is part of local validation. Before any production rollout,
review the migration, verify the intended project's migration history, test
the behavior in a non-production Supabase project, and obtain explicit
approval.
