# Security model and verification

Phase 3 establishes the authorization boundary before any parking CRUD or
photo workflow is added.

## Client boundary

The Flutter Web bundle contains only:

- The Supabase project URL.
- The public publishable/anon key.

Those values identify the project but do not replace authorization. The
database and Storage policies are the security boundary. Never expose a
service-role key, database password, JWT signing secret, or other privileged
credential to the browser, GitHub, generated web assets, or logs.

Configuration is supplied with `--dart-define` and validated before
`Supabase.initialize` runs. Missing configuration produces an explicit setup
page instead of a fake client or a silent unauthenticated mode.

The production GitHub Actions workflow reads `SUPABASE_URL` and
`SUPABASE_PUBLISHABLE_KEY` from GitHub secret settings and passes them to the
same compile-time defines. These values are intentionally visible in the
browser release because the URL and publishable/anon key identify a public
client; the workflow must never receive or embed a Supabase secret/service-role
key. Cloudflare deployment credentials are used only by the workflow and are
not application configuration.

## Authentication

The current UI supports only email/password sign-in and local sign-out. There
is no public registration flow. The first user must be created by an
administrator in the Supabase Dashboard.

The auth repository keeps Supabase calls out of widgets and exposes only the
session state needed by the auth gate. Authentication errors are displayed to
the user without logging credentials.

## Database authorization

`public.parking_sessions` has `created_by uuid not null` referencing
`auth.users`. RLS is enabled, `anon` has no table privileges, and the
`authenticated` role receives only the required table operations.

Each operation has its own owner policy:

- Select: `created_by = auth.uid()`.
- Insert: the inserted `created_by` must equal `auth.uid()`.
- Update: the existing and new owner must equal `auth.uid()`, preventing
  ownership transfer.
- Delete: the existing owner must equal `auth.uid()`.

The migration also validates positive duration values, a supported duration
unit, and a trimmed plate number length. The maximum allowed duration is
deliberately deferred to the Phase 4 domain service.

## Storage authorization

The `vehicle-photos` bucket is private. It is not made public as a fallback.
The expected object path is:

```text
{auth.uid()}/{parking_session_id}/{filename}
```

Each Storage policy checks all of the following:

1. The bucket is `vehicle-photos`.
2. The first path folder equals the current authenticated user's ID.
3. The second path folder identifies a `parking_sessions` row owned by that
   user.

This avoids granting access to arbitrary objects under a user's folder and
prevents cross-user access through a guessed session ID. The future upload
sequence is row first, upload second, and row cleanup on upload failure.

## Verification checklist

Run the source-level Flutter checks:

```powershell
dart format .
flutter analyze
flutter test
flutter build web --release
```

Inspect the built output and source tree for privileged credentials:

```powershell
rg -n -i "service[-_ ]?role|sb_secret|jwt secret|database password" `
  lib web build README.md docs supabase
```

The expected result is no real credential. Placeholder names and
documentation references are acceptable.

When the Supabase CLI and Docker are installed, run:

```powershell
supabase test db
```

The repository contains:

- `supabase/tests/parking_sessions_rls.test.sql`
- `supabase/tests/vehicle_photos_rls.test.sql`

These checks are source-controlled but were not executed in the current
environment because Supabase CLI and Docker were unavailable. No hosted
project, bucket, migration, user, or policy is claimed as verified until the
manual checklist is completed.

After deployment, verify the actual Pages origin in Supabase Auth URL
Configuration and run the two-account database and private-Storage checks
from [deployment.md](deployment.md). A successful frontend build is not proof
of hosted RLS or Storage isolation.

## Review requirements for later phases

Before adding CRUD or photo UI, confirm that:

- Every database query runs through the authenticated Supabase client.
- No service-role credential or custom bypass endpoint is introduced.
- The row is created before a photo upload.
- Failed uploads remove the row and any partial object.
- Photo deletion occurs before deleting its database row.
- User-visible errors do not include access tokens, passwords, or raw
  privileged responses.
