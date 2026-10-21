# Device-session limits

The app enforces concurrent device limits for tenant owners and members using
PostgreSQL and a Supabase Custom Access Token Hook. Enforcement is tenant
scoped and server-side; Flutter registration alone is not an authorization
boundary.

## Policy

- The platform default starts at **1 device per account**. Super Admins can
  change the platform default from the Admin screen.
- A nullable tenant limit overrides the platform default. A null value means
  that the tenant inherits the current platform default.
- A per-account override is scoped to `(tenant_id, user_id)` and takes
  precedence over the tenant limit.
- Precedence is **account override > tenant policy > platform default**.
  Limits are integers from 1 through 50.
- The default stale-session expiry is 30 days and can be configured from 7
  through 365 days. Lowering a limit does not revoke existing registrations;
  it blocks new installations until active usage is below the new limit.
- The same random installation ID can have multiple Auth sessions and still
  consumes one device slot per tenant. Each Auth session is stored separately
  and can be revoked. One Auth session ID is bound to one installation ID.
- Each tenant has an independent allowance. Registering a device in one
  tenant does not consume a slot in another tenant for the same Auth user.
- Super Admins are exempt. New tenants receive a nullable policy row and
  inherit the live platform default. Existing tenants are backfilled with
  nullable policy rows; existing memberships and parking data are unchanged.
  No device records are fabricated for sessions that predate this feature.

## Enforcement and lifecycle

Supabase's Custom Access Token Hook receives the Auth `session_id` but not a
browser installation ID. The initial password-authenticated token is
therefore issued before the app can register the device. Before loading
tenant-owned rows or private photos, Flutter calls
`list_my_device_session_tenant_choices()` to retrieve only that user's active
tenant names and roles, then calls `register_device_session()` for the
selected tenant. The database derives the user and Auth session IDs from the
JWT, serializes concurrent registrations, binds the session to the supplied
opaque installation ID, and atomically checks the effective limit.

Until registration succeeds, `is_tenant_member()` denies access to tenant
tables and private vehicle-photo objects through existing RLS policies. The
pre-registration RPCs expose only the user's own tenant choices and device
session summaries; they do not expose parking rows or photos. A limit-rejected
session can view and revoke only its own existing device registrations, retry
registration, or sign out. If the user belongs to multiple tenants, the limit
screen lets them select another active tenant and retry there; each tenant's
allowance remains independent.

For token refreshes, the Custom Access Token Hook requires an active,
non-stale device-session record and updates its activity time. A revoked,
signed-out, or expired registration fails tenant RLS immediately and cannot
be restored by refreshing its old Auth session. Explicit logout releases the
current Auth session from every tenant. User and Super Admin revocation is
tenant-scoped and writes an audit event.

Stale rows are expired opportunistically during registration and session
listing. Inactivity shorter than the configured cutoff does not free a slot.
The migration does not modify Supabase's internal Auth tables or install a
paid scheduler. An Auth session invalidated outside this app will stop
refreshing at Supabase, but its app registration can continue to count until
it is explicitly revoked or reaches the configured stale cutoff.

If the release RPC fails, the app does not silently report a successful
logout: it keeps the user signed in and exposes the error so logout can be
retried. If the browser is closed without release, the 30-day stale policy is
the recovery path.

## Device identity limitations

The web client creates a cryptographically random UUIDv4 and stores it in
`shared_preferences` (browser local storage). It is an opaque installation
identifier, not proof of a physical device. Users can clear browser storage,
copy the value, or spoof it. The feature does not trust browser fingerprints,
IP addresses, or user-agent strings. A cleared ID paired with an existing
Auth session must be reconciled by revoking the old registration or signing
in again.

## Local validation

The PostgreSQL policy and RLS tests are in
`supabase/tests/device_session_limits.test.sql`. The actual concurrent
last-slot race test uses two independent PostgreSQL connections and the
existing `pg` dependency; it accepts only a loopback connection string.
Docker, `psql`, and a local Supabase database were unavailable during
implementation, so database tests are authored but not executed.

With Docker installed, start and rebuild only the local Supabase database,
then run pgTAP:

```powershell
# Use the disposable local hook-secret setup documented in
# tenant-member-management.md before running these local-only commands.
supabase start
supabase db reset
supabase test db --local
```

`supabase db reset` drops and recreates the local Supabase database. Do not
point it at a hosted project. For the two-connection test, use the default
local Supabase PostgreSQL URL:

```powershell
$env:DEVICE_SESSION_TEST_DATABASE_URL = "postgresql://postgres:postgres@127.0.0.1:54322/postgres"
npm --prefix local-api run test:device-session-concurrency
Remove-Item Env:\DEVICE_SESSION_TEST_DATABASE_URL
```

The test accepts only the local Supabase PostgreSQL endpoint (`postgres` on a
loopback host at port `54322`, database `postgres`) before connecting.
Flutter validation from the repository root:

```powershell
dart format .
flutter analyze
flutter test
flutter build web --release
git diff --check
```

## Migration and Auth Hook rollout

The versioned migration is
`supabase/migrations/20261024090000_device_session_limits.sql`. Local
`supabase/config.toml` enables the Custom Access Token Hook for local
development. The migration was applied to the verified production project
`parking-management` as part of the approved tenant-member rollout. The
production Auth Hook configuration was not changed or verified by that
rollout; do not assume that setting `supabase/config.toml` activated the hook
for the hosted project.

After deployment, `supabase db lint --linked --schema public` identified
PostgreSQL return-type errors in
`list_tenant_member_device_session_policies`,
`list_tenant_device_sessions`, and `list_device_session_audit_events`.
`auth.users.email` is `character varying`, while those functions declare
their email result columns as `text`. The follow-up migration
`20261024110000_fix_device_session_email_return_types.sql` casts those values
explicitly. It was applied to the verified `parking-management` project
after separate approval, and linked migration history confirms it is
recorded. A post-application lint attempt failed before schema inspection
because PostgreSQL authentication failed for the CLI's temporary login role;
`SUPABASE_DB_PASSWORD` was absent from the process environment. Do not report
the affected RPCs as lint-verified until linked schema lint succeeds.

After local review and with explicit approval for the intended environment,
inspect pending remote migrations without applying them:

```powershell
supabase db push --dry-run --linked --skip-vault
```

The local configuration references `SEND_EMAIL_HOOK_SECRET`. If it is unset
or invalid, the CLI rejects the configuration before connecting, even for a
dry run. For a migration-only preview, provide a temporary format-valid
`v1,whsec_...` value in the current PowerShell process and use `--skip-vault`
so that placeholder is not synchronized to Supabase Vault. Do not store a
placeholder in `config.toml` or use it to configure the hosted Auth Hook.

Review the preview and migration SQL before any approved write operation. Do
not run `supabase db push`, `supabase config push`, or deploy a frontend as
part of validation. Production Auth Hook activation and migration application
are separate, explicitly approved rollout steps.
