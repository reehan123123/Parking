# Supabase setup

This document describes the manual setup for Phase 3. It is intentionally
written so that a developer can apply and verify the source-controlled
configuration without putting credentials in the Flutter project.

## 1. Create the project

1. Create a Supabase project in the intended account and region.
2. In **Project Settings > API**, copy the project URL and the publishable key
   (called the anon key in older Supabase projects).
3. Keep the service-role key private. It is not required by this Flutter app
   and must never be placed in Dart code, browser configuration, Git, or logs.
4. In **Authentication > Providers**, enable Email. For a private
   administrator-created account, disable public sign-ups if that is enabled
   for the project.

This repository has not created or inspected a hosted project. Replace the
placeholder values below only in your local shell:

```powershell
$env:SUPABASE_URL = "https://your-project-ref.supabase.co"
$env:SUPABASE_PUBLISHABLE_KEY = "sb_publishable_replace_me"
```

The Flutter app receives these values through compile-time defines rather than
from a runtime `.env` asset:

```powershell
flutter run -d chrome `
  --dart-define=SUPABASE_URL=$env:SUPABASE_URL `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=$env:SUPABASE_PUBLISHABLE_KEY
```

PowerShell expands the values before Flutter embeds them. Do not record the
command in a shared log or commit a script containing real values.

For production, configure the same two public values as GitHub Actions secrets
named `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`. The deployment workflow
passes them to Flutter with `--dart-define`; it does not read `.env` files and
must never receive a secret/service-role key.

## 2. Apply the migration

The migration file is:

```text
supabase/migrations/20261014160000_create_parking_sessions_security.sql
```

It creates:

- `public.parking_sessions` with ownership, duration, timestamp, and
  non-blank plate constraints.
- Indexes for `plate_number`, `expires_at`, and `created_by`.
- An `updated_at` trigger.
- Authenticated-only table grants and owner-only select, insert, update, and
  delete policies.
- A private `vehicle-photos` Storage bucket.
- Storage policies requiring both the authenticated-user folder and an owned
  `parking_sessions` row.

### Supabase CLI path

Install the Supabase CLI using the official instructions, authenticate, and
link the local directory to the intended project. Then apply migrations:

```powershell
supabase login
supabase link --project-ref your-project-ref
supabase db push
```

The CLI and Docker were not available in the development environment used for
this phase, so these commands have not been executed here. Do not treat a
successful local Flutter build as proof that the migration reached Supabase.

### SQL Editor path

Alternatively, open the Supabase Dashboard SQL Editor, review the migration,
and run it against the intended project. Confirm that:

```sql
select id, name, public
from storage.buckets
where id = 'vehicle-photos';

select relrowsecurity
from pg_class
where oid = 'public.parking_sessions'::regclass;
```

The bucket query must show `public = false`, and the table query must show
`relrowsecurity = true`.

## 3. Create the initial private user

1. Open **Authentication > Users**.
2. Choose **Add user**.
3. Create the administrator's email/password account.
4. Use that account only through the private sign-in page.
5. Do not add a public sign-up button to the application.

Email confirmation behavior depends on the project's Auth settings. If email
confirmation is enabled, complete the confirmation flow before testing the
Flutter sign-in page.

After the Cloudflare Pages URL is known, set that exact HTTPS origin as the
Supabase Auth Site URL and add only the required exact redirect URLs. Keep
local development URLs separate from the production origin. The current app
uses password sign-in rather than an OAuth callback, but Auth URL settings also
affect email confirmation and future password-reset links.

## 4. Verify the policies

The repository includes pgTAP-oriented checks:

```text
supabase/tests/parking_sessions_rls.test.sql
supabase/tests/vehicle_photos_rls.test.sql
```

With the Supabase CLI and Docker available, run:

```powershell
supabase test db
```

The tests cover anonymous denial, owner visibility, cross-owner denial,
ownership-transfer prevention, and the private Storage bucket policy
presence. Hosted project verification still requires running the checks
against the linked project or inspecting the resulting catalog state.

## 5. Local troubleshooting

- A build without `SUPABASE_URL` or `SUPABASE_PUBLISHABLE_KEY` intentionally
  shows **Supabase configuration required**.
- A valid URL with an invalid key shows an initialization error; check the
  project and key copied from the same Supabase project.
- Authentication failures are shown in the sign-in page without logging the
  password or token.
- The Phase 5 photo flow creates the owned database row before uploading to
  `{user-id}/{parking-session-id}/{filename}`. If the upload fails, it removes
  the Storage object before deleting the database row because the Storage
  policy checks the row's ownership. If cleanup fails, the row is retained and
  the form exposes a retry action.
- The Phase 5 form supports one optional photo, accepts JPEG/PNG/WebP images,
  uses the official `camera: 0.12.1` package for an on-demand live browser
  preview, and keeps `image_picker` for normal file selection. File-picker
  images request an approximately 1600-pixel/quality-85 transform where
  supported; captured and selected images larger than 10 MB are rejected.
  Camera behavior still depends on localhost/HTTPS, browser support, and user
  permissions; file selection remains the fallback.
