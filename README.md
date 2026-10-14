# Parking Management PWA

Private parking management Progressive Web App built with Flutter Web. The
application uses Supabase for authentication, PostgreSQL data, and private
photo storage, and is intended for free-tier-friendly static hosting.

## Current status

Phase 9 deployment preparation is implemented locally: public Supabase
configuration, private email/password sign-in and sign-out, the
`parking_sessions` migration,
owner-only database policies, a private `vehicle-photos` bucket policy set,
the tested duration service, authenticated parking entry/photo/OCR flow, and
dashboard, history, details, edit, and delete flows are present. Phase 4
through Phase 7 are checkpointed in Git. Cloudflare deployment, hosted
Supabase verification, and mobile/PWA production checks remain pending.

No hosted Supabase project, migration, bucket, policy, or user is assumed to
exist. Apply and verify the SQL against the intended project before using the
application with real data.

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

## Supabase setup

Follow [docs/supabase.md](docs/supabase.md) to create a project, apply the
migration, create the initial private user, and run the local verification
commands.

See [docs/parking-entry.md](docs/parking-entry.md) for the entry form, photo
limits, persistence sequence, edit behavior, cleanup handling, and manual
checks. See [docs/parking-session-management.md](docs/parking-session-management.md)
for dashboard, history, details, search, signed photos, editing, deletion, and
refresh behavior. See [docs/deployment.md](docs/deployment.md) for the
GitHub Actions, Cloudflare Pages, Supabase production, verification, and
rollback handover.

The source-controlled SQL is under `supabase/migrations/`. It creates the
database table, indexes, `updated_at` trigger, owner-only RLS policies, and
the private `vehicle-photos` bucket policies. The SQL is not applied to a
remote project by this repository.

## Security

The browser receives only the Supabase project URL and publishable key. Never
put a service-role key or another privileged secret in Flutter code, web
assets, Git, or logs. RLS remains enabled, the photo bucket remains private,
and Storage object paths must begin with:

```text
{authenticated-user-id}/{parking-session-id}/{filename}
```

Read [docs/security.md](docs/security.md) for the authorization model,
verification checklist, and known manual checks.

## Scope guardrails

The first release remains web-only and free-tier friendly. It does not include
native app builds, payments, public self-registration, custom backend
services, or full offline operation.
