# Parking Management PWA

Private parking management Progressive Web App built with Flutter Web. The
production application uses Supabase for authentication, PostgreSQL data, and
private photo storage, and is intended for free-tier-friendly static hosting.
An opt-in, loopback-only development API can connect the app to one local
PostgreSQL database without Docker or a hosted Supabase development project.

## Current status

The application includes authenticated parking entry and private photo
handling, dashboard/history/details/edit/delete flows, tenant-scoped access,
and a role-gated Super Admin area. Super Admins can view parking across
tenants, create parking entries for a selected active tenant, rename tenants,
reversibly archive or restore tenants, and manage existing Auth-user
memberships. Tenant owners can be assigned from an existing Auth account or
onboarded by the server-side Supabase Edge Function. Owners can add existing
member accounts or provision a new tenant-scoped login through a separate
authenticated Edge Function. New accounts receive a one-time temporary
password and must change it before accessing tenant data. The tenant
authorization model is enforced by PostgreSQL RLS. Review the Supabase
migration history, deploy the three onboarding Edge Functions, and provision
the initial Super Admin before using these features.

Tenant member limits and independent parking-entry permissions are now
implemented in source. New tenants allow one member by default (owners do
not count); only Super Admins can change the limit. Owners can manage
existing or newly provisioned member accounts in their own tenant. See
[docs/tenant-member-management.md](docs/tenant-member-management.md) before
local testing or rollout.

Configurable tenant-scoped device-session limits are implemented in source.
The initial policy is one device, with tenant and per-account overrides,
server-side registration, and a Supabase Auth refresh hook. The feature has
not been migrated or activated on the hosted project; see
[docs/device-session-limits.md](docs/device-session-limits.md) before testing
or planning a rollout.

## Local development

The project requires the stable Flutter SDK with web support. From the
repository root:

```powershell
flutter pub get
dart format .
flutter analyze
flutter test
```

The app intentionally requires public Supabase configuration at compile time.
Use the project URL and publishable key for a configured local run:

```powershell
flutter run -d chrome `
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_replace_me
```

The same defines are required for a configured release build:

```powershell
flutter build web --release `
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_replace_me
```

`.env.example` documents the variable names only. Flutter does not load that
file automatically, and real values must not be committed. A build without
the defines shows an explicit configuration-required page.

### Use one local PostgreSQL database

For local development without Docker or a hosted Supabase project, follow
[docs/local-development.md](docs/local-development.md). The local API is
opt-in and binds only to `127.0.0.1`; it does not copy production data.
Production builds continue to use Supabase.

## Supabase setup

Follow [docs/supabase.md](docs/supabase.md) to configure a project, apply the
migrations, provision the initial Super Admin, create tenants, and run the
verification commands. The local PostgreSQL workflow is separate and does
not apply or modify hosted Supabase migrations.

See [docs/parking-entry.md](docs/parking-entry.md) for the entry form, photo
limits, persistence sequence, edit behavior, cleanup handling, and manual
checks. See [docs/parking-session-management.md](docs/parking-session-management.md)
for dashboard, history, details, search, signed photos, editing, deletion, and
refresh behavior. See [docs/tenant-member-management.md](docs/tenant-member-management.md)
for member capacity, permissions, and local-only database validation. See
[docs/deployment.md](docs/deployment.md) for the
GitHub Actions, Cloudflare Pages, Supabase production, verification, and
rollback handover.

The source-controlled SQL is under `supabase/migrations/`. It creates the
parking-session and tenant tables, indexes, triggers, tenant-membership and
Super Admin RLS policies, private photo policies, tenant lifecycle and
membership-management operations, the temporary-password access gate, and
the versioned device-session policy and enforcement work, member-capacity
and entry-permission enforcement.
Migration files are reviewable source; applying them to a hosted project is a
separate operation.

## Security

In production/default mode, the browser receives only the Supabase project
URL and publishable key. In local mode, the browser talks to the loopback API
and never receives PostgreSQL credentials. Never put a service-role key,
provider secret, or another privileged secret in Flutter code, web assets,
Git, or logs. Supabase RLS and the private photo bucket remain the production
access boundary. Existing photo paths remain:

```text
{session-created-by-user-id}/{parking-session-id}/{filename}
```

Read [docs/security.md](docs/security.md) for the authorization model,
verification checklist, and known manual checks.

## Scope guardrails

The first release remains web-only and free-tier friendly. It does not include
native app builds, payments, public self-registration, OCR, third-party image
processing, or full offline operation.
