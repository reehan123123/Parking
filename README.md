# Parking Management PWA

Private parking management Progressive Web App built with Flutter Web. The
application uses Supabase for authentication, PostgreSQL data, and private
photo storage, and is intended for free-tier-friendly static hosting.

## Current status

The application includes authenticated parking entry and private photo
handling, dashboard/history/details/edit/delete flows, tenant-scoped access,
and a role-gated Super Admin tenant-creation screen. The tenant authorization
model is enforced by PostgreSQL RLS. To enable it on a hosted project, review
and apply the tenant-administration migration, then provision the initial
Super Admin with the documented SQL operation. The hosted migration and role
assignment have not been verified.

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

Follow [docs/supabase.md](docs/supabase.md) to configure a project, apply the
migrations, provision the initial Super Admin, create tenants, and run the
verification commands.

See [docs/parking-entry.md](docs/parking-entry.md) for the entry form, photo
limits, persistence sequence, edit behavior, cleanup handling, and manual
checks. See [docs/parking-session-management.md](docs/parking-session-management.md)
for dashboard, history, details, search, signed photos, editing, deletion, and
refresh behavior. See [docs/deployment.md](docs/deployment.md) for the
GitHub Actions, Cloudflare Pages, Supabase production, verification, and
rollback handover.

The source-controlled SQL is under `supabase/migrations/`. It creates the
parking-session and tenant tables, indexes, triggers, tenant-membership and
Super Admin RLS policies, and private photo policies. Migration files are
reviewable source; applying them to a hosted project is a separate operation.

## Security

The browser receives only the Supabase project URL and publishable key. Never
put a service-role key, provider secret, or another privileged secret in
Flutter code, web assets, Git, or logs. RLS remains enabled, the photo bucket
remains private, and tenant membership—not a browser-supplied role or tenant
ID—is the access boundary. Existing photo paths remain:

```text
{session-created-by-user-id}/{parking-session-id}/{filename}
```

Read [docs/security.md](docs/security.md) for the authorization model,
verification checklist, and known manual checks.

## Scope guardrails

The first release remains web-only and free-tier friendly. It does not include
native app builds, payments, public self-registration, OCR, third-party image
processing, or full offline operation.
