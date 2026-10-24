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
through the authenticated `create-tenant-owner` Edge Function. Tenant owners
and Super Admins can add members through the authenticated
`create-tenant-member` Edge Function. Existing Auth accounts are assigned
without changing their credentials. A missing member account is created with
a cryptographically random temporary password, marked for a forced password
change, email-confirmed by the administrative flow, and linked only to the
requested tenant. This does not independently verify email ownership; the
authorized manager must share the password securely. The password is returned
only to that manager for one-time display; it is not persisted or logged by
the application.

New owner and member accounts receive a server-set `app_metadata` flag
requiring a password change. `AuthGate` routes them to the password-change
screen, while `is_super_admin()` and `is_tenant_member()` deny tenant,
parking-session, and private-photo access until the change is completed by the
`complete-temporary-password-reset` Edge Function. The client cannot set or
clear the flag. The member function validates the caller's management
authority through database RPCs and checks capacity before creating an Auth
identity; the existing `add_tenant_member` RPC remains the atomic final
capacity check. Privileged Auth Admin access remains server-side.

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

## Platform maintenance mode

The global maintenance setting is stored in a singleton database row that
authenticated clients cannot read or modify directly. Status is exposed
through an authenticated RPC, and the update RPC verifies the caller with
`public.is_super_admin()`. The app checks this state after sign-in, shows a
maintenance screen to non-admin users until the server-side end time, and
allows Super Admins to continue using the app. The status is polled while the
app is open and is rechecked at expiry.

This is an app-UI gate, not a database-wide outage control: direct Supabase API
requests remain governed by the existing RLS policies and are not disabled.
The local API development backend does not implement this platform setting.

## Tenant and database authorization

`public.tenants` identifies parking workspaces.
`public.tenant_memberships` maps Auth users to workspaces with `owner` or
`member` role. Tenant owners have full access within their tenant. Member
accounts receive independent View, Add, Edit, and Delete permissions;
Super Admins retain platform-wide access under the existing role policy.

The member-management migration stores a positive tenant member limit
(default 1, maximum 50) in `public.tenants.member_limit`; owners do not consume
slots. Active usage is the count of member-role membership rows. Existing
memberships are preserved during the default backfill, and existing members
retain their former full access. New members default to View-only. There is no
member invitation, account-provisioning, or soft-deletion flow.

Database RPCs serialize member additions and owner-to-member role changes
with a tenant-row lock before checking capacity. A full tenant receives the
stable `MEMBER_LIMIT_REACHED` error and structured limit/usage details.
Super Admins alone can change limits; owners can manage member-role accounts
only in their own tenant. Authenticated clients cannot directly create Auth
users or change membership roles, permission flags, or member limits.
Membership and policy changes are recorded in tenant-scoped audit events.
Removal revokes that member's registered device sessions in the tenant but
preserves the shared Auth identity and parking history.

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

- Select requires View; insert requires Add and the caller's Auth user ID as
  `created_by`; update requires Edit; delete requires Delete (with a narrow
  pending-photo cleanup exception for the creator). Owners and
  database-recognized Super Admins retain full access.
- Every operation checks the row's tenant and the registered active
  device-session gate for ordinary tenant users. A client-supplied tenant ID,
  membership role, or permission flag cannot grant access.
- Non-admin users cannot change a session's `tenant_id` or `created_by`.
- Authenticated users cannot insert or update rows in `public.super_admins`.
- Tenant creation is restricted to Super Admins. The authenticated
  `create-tenant-owner` Edge Function provisions a missing owner account
  server-side, then calls the idempotent `create_tenant_for_request` RPC to
  assign the owner in the same transaction as tenant creation. The
  `create-tenant-member` Edge Function similarly provisions missing member
  accounts and calls the atomic `add_tenant_member` RPC. Existing users keep
  their current passwords.
- Tenant-creation request IDs make retries idempotent. If Auth account
  creation succeeds but tenant setup cannot be confirmed, the UI preserves
  the temporary password and allows a retry without silently claiming the
  tenant was created.
- Tenant rename, archive/restore, and membership changes are performed through
  Super Admin-only security-definer functions; authenticated clients have no
  direct tenant or membership write grants.

The Flutter repository sends an explicit selected-tenant filter for list and
summary queries. A global Super Admin view omits that filter; RLS still
enforces the caller's real role and entry permission in both cases. Direct-ID
lookups and mutations also rely on RLS rather than trusting client-side
ownership filters. The owner Settings screen and Super Admin tenant manager
call scoped RPCs; ordinary members are not granted owner-management
capabilities.

## Concurrent device-session limits

Tenant owners and members are gated by a PostgreSQL device-session registry.
The platform default is one device; tenant policy and per-account overrides
are resolved server-side in the order account > tenant > platform. Each
account override is tenant scoped. Super Admins are exempt, and one
installation may have multiple Auth sessions while consuming one slot.

The Auth Hook cannot receive the browser installation ID, so the initial
password sign-in can issue a token before registration. That token cannot
read tenant rows or private photos: `is_tenant_member()` requires the current
JWT `session_id` to have an active device registration, and the client
registers before loading the workspace. The Custom Access Token Hook denies
refresh for a missing, stale, signed-out, or revoked registration. Revocation
therefore blocks RLS immediately and prevents an old refresh token from
reopening the session.

The browser installation ID is a random UUID stored locally. It can be
cleared, copied, or spoofed and is not a physical-device credential. No
browser fingerprint, IP address, or user-agent is used. The default stale
expiry is 30 days, not a short inactivity timeout; existing installations
are not forcibly revoked when an administrator lowers a limit. See
[device-session limits](device-session-limits.md) for the enforcement flow,
recovery, validation, and rollout commands. Hosted migration and Auth Hook
activation remain separate and require explicit approval.

## Private vehicle-photo authorization

The `vehicle-photos` bucket remains private. The object path remains:

```text
{session-created-by-user-id}/{parking-session-id}/{filename}
```

Each Storage operation verifies that the second path component identifies a
parking session, that the first component matches that row's `created_by`,
that the object name exactly matches the row's recorded `photo_path`, and
that the caller has the matching View, Add, Edit, or Delete permission for
the session tenant. Add permission has a narrow creator-only exception for
uploading and cleaning up a pending photo. This preserves existing object
paths while granting access at the tenant boundary. Signed URLs are created
only after the associated session and photo path are verified through the
authenticated client.

The save sequence remains row first, Storage upload second, with cleanup on
failure. Photo deletion precedes session deletion; cleanup failures remain
visible and retryable. Lists do not download photo bytes.

## OneSignal parking reminders and in-app notifications

The replacement implementation uses the OneSignal Web SDK v16 as the only
push-delivery provider. Its page SDK and bridge are loaded by
`web/index.html`; the official OneSignal worker is kept under
`/push/onesignal/` with its own service-worker scope. Flutter's root worker,
manifest, bootstrap, asset caching, offline behavior, and PWA installation
remain separate and are not replaced.

Push permission is requested only after a signed-in user selects **Enable**
in Settings. The client identifies the authenticated account using its stable
Supabase user UUID as OneSignal's `external_id`; it does not use email,
tenant IDs, or browser fingerprints. Logout and account changes synchronize
the OneSignal identity. The app reports unsupported, permission, pending,
enabled, disabled, and failed states. OneSignal logout detaches the current
browser subscription from the previous identity; it does not delete other
devices' subscriptions or recall already queued messages.

The scheduler's sole intended delivery path is the Supabase Edge Function
`dispatch-parking-notifications`, called every five minutes through
`pg_cron`/`pg_net`. It checks the current expiry, outstanding balance
(`total_charge > paid_amount`), tenant validity, and owner/View membership
before each send. Partial payments continue reminders; full payment resolves
them; a reversal can reactivate reminders. Recipients are resolved server-side
from the parking session's current tenant memberships. The client cannot
choose a tenant or recipient.

Push content is intentionally generic: title **Parking Expired**, body
**Full-Amount Not Paid**, and an HTTPS link containing only the exact session
ID. It omits payment amounts, plates, customer details, and tenant IDs.
Notification clicks preserve the destination through authentication and then
load the session through the normal authenticated repository and RLS path.
The URL is never treated as authorization. In-app alerts use one mutable row
per recipient/session/type, reopen as unread for a new reminder interval, and
resolve when the balance is paid. The notification center polls about once
per minute only while a signed-in app is active with one tenant selected; it
does not provide background in-app alerts while the app is closed.

`ONE_SIGNAL_APP_ID` is public client configuration, supplied to Flutter as a
compile-time define and to the Edge Function at runtime. `ONE_SIGNAL_API_KEY`
is server-side only and belongs only in Supabase Edge Function secrets. The
scheduled invocation also requires `PARKING_NOTIFICATION_CRON_SECRET`; its
matching project URL and cron secret are read from Supabase Vault. None of
these values may be committed or printed. A service-role key, OneSignal REST
API key, and cron secret must never appear in Flutter code, browser requests,
build arguments, generated assets, or build logs. See
[Supabase setup](supabase.md) and
[production deployment](deployment.md) for the configuration boundary.

The forward migration
`20261025150000_onesignal_parking_notifications.sql` and replacement client,
worker, and Edge Function are local source changes only. They have not been
applied or deployed to production. The previously verified production
deployment used the legacy Web Push/VAPID sender; production migrations,
secrets, subscriptions, and scheduled jobs have not been changed by this
work. Historical migrations remain immutable, and the legacy subscription
and delivery data and hosted VAPID secrets are retained pending a separately
approved cleanup. The current process did not expose `ONE_SIGNAL_APP_ID` or
`ONE_SIGNAL_API_KEY`; no values were read or printed, and remote Supabase or
OneSignal configuration was not verified.

The migration caps claims at 20 sessions per run to bound work, so a larger
backlog may be processed across multiple five-minute runs. OneSignal's
message-volume limits may also constrain high-volume tenants. Push requires
HTTPS, browser permission, and platform support. Desktop and mobile background
push have not been verified on the relevant production browsers and operating
systems; do not infer device behavior from local tests.

## Self-service "Remember me" and password recovery

Distinct from the administrative temporary-password-reset flow above, the
sign-in screen offers two self-service, free-tier Supabase Auth features:

- **Remember me**: an optional checkbox that stores only the entered email
  address locally (via `shared_preferences`) so it can be prefilled on the
  next visit. It never stores a password, access token, or refresh token.
  Supabase's own session persistence and refresh behavior are unchanged;
  unchecking the box clears only the remembered email, not any active
  session.
- **Forgot password**: a dialog that calls Supabase's built-in
  `resetPasswordForEmail()` using the current page origin as the redirect.
  The confirmation message is neutral ("if an account exists...") on both
  genuine success and an unrecognized email, so the flow never reveals
  whether an email address has an account. Only real failures (network
  errors, rate limiting) show a distinct, honest error.
- **Password recovery**: when the user opens the emailed recovery link,
  Supabase fires a `passwordRecovery` auth event rather than a distinct URL
  path. `AuthGate` listens for this event and renders the password-reset
  screen *before* evaluating normal signed-in/signed-out state, so the
  temporary recovery session Supabase establishes can never fall through to
  the authenticated application. After the user sets a new password (or
  cancels), the app signs out of that temporary session and returns to the
  normal sign-in screen.

This flow uses only `resetPasswordForEmail()` and `updateUser()` from the
existing `supabase_flutter` client. The `PARKING_BACKEND=local` development
mode has no email capability, so its "Forgot password?" link is shown but
disabled with an explanatory tooltip.

### Outgoing auth email delivery: Supabase "Send Email" hook + Brevo

Supabase's built-in email sender is hard-capped at **2 emails/hour,
project-wide** on the free plan, and that cap cannot be raised by a plan
upgrade — only by configuring a custom SMTP provider or a Send Email hook.
This project uses the **Send Email hook** (`supabase/functions/send-email`),
a Supabase Edge Function that Supabase Auth calls for every outgoing auth
email (signup, invite, magic link, recovery, email change, reauthentication,
and account-activity notifications) in place of its own built-in sender. The
function:

- Verifies the request is genuinely from Supabase using the Standard
  Webhooks signature scheme (`standardwebhooks`) and a secret known only to
  Supabase and this function (`SEND_EMAIL_HOOK_SECRET`, an Edge Function
  secret — never committed, never logged).
- Builds the appropriate subject/body per `email_action_type`, reusing
  Supabase's own `/auth/v1/verify?token=...&type=...&redirect_to=...` link
  format so existing redirect/route handling (see `AuthGate` above) is
  unchanged.
- Sends the message through **Brevo**'s transactional email API
  (`https://api.brevo.com/v3/smtp/email`), a free-tier provider (300
  emails/day) configured with its own sender address/API key as Edge
  Function secrets (`BREVO_API_KEY`, `EMAIL_SENDER_ADDRESS`,
  `EMAIL_SENDER_NAME`) — never committed, never logged, never exposed to the
  Flutter client.

The hook is wired in `supabase/config.toml` under `[auth.hook.send_email]`
and activated on the remote project via `supabase config push` (no Supabase
Dashboard interaction required). No service-role key or other privileged
credential is present in Dart/browser code; the function only ever runs
server-side.

**Per-account recovery email cap**: independent of Supabase's own limits,
the hook enforces an application-level cap of **6 password-recovery emails
per account per UTC day**. Each "recovery"-type request first calls the
`record_password_reset_attempt(email)` SQL function (migration
`20261021110000_password_reset_rate_limit.sql`), which atomically increments
a per-email, per-day counter in `public.password_reset_request_log` using
`SECURITY DEFINER`, with `EXECUTE` granted only to `service_role` and RLS
enabled denying all other access. Once the 6th email for that account/day
has been sent, further attempts that same day are rejected with the same
HTTP 429 the app already displays for Supabase's native per-address cooldown
("Too many reset requests. Wait a few minutes and try again."), so no new
client-visible behavior or account-existence signal is introduced.

**Free-tier email limits (current)**:
- Brevo: 300 emails/day (project-wide), used for every auth email once the
  hook is enabled — well above Supabase's built-in 2/hour cap.
- Application-level: 6 recovery emails per account per UTC day (see above).
- Supabase's own built-in `auth.email.max_frequency` (60s per address) and
  2/hour built-in cap no longer apply to outgoing mail once the hook is
  active, since the hook fully replaces Supabase's SMTP-based sending.

This is still a free-tier-only architecture — Brevo's free transactional
tier, no paid SMTP, no paid Supabase add-on — but it is not Supabase's
*built-in* email service; it is an Edge Function plus a third-party free
provider, which the user explicitly requested to bypass the built-in cap.



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
`supabase/tests/tenant_owner_onboarding.test.sql`,
`supabase/tests/device_session_limits.test.sql`, and
`supabase/tests/tenant_member_limits_permissions.test.sql`. Run them only
against the local Supabase database:

```powershell
supabase test db --local
```

The member and device concurrency tests also require an explicit local
Supabase PostgreSQL URL using the `postgres` role, a loopback host, port
`54322`, and the `postgres` database; see
[tenant member management](tenant-member-management.md) and
[device-session limits](device-session-limits.md). Docker is unavailable in
the current environment, so pgTAP and PostgreSQL concurrency tests have not
been executed. Hosted RLS, two-user tenant isolation, private-photo access,
live Super Admin provisioning, and production migration state remain
unverified.

Inspect for privileged credential patterns:

```powershell
rg -n -i "service[-_ ]?role|sb_secret|jwt secret|database password" `
  lib web build README.md docs supabase
```

Documentation references and placeholder variable names are expected; no real
privileged values may appear in source, release assets, or logs.
