# Production deployment and handover

The production target is a static Flutter Web release on Cloudflare Pages
using the free `pages.dev` hostname and the selected project name
`parking-management`. The application
continues to use Supabase for authentication, PostgreSQL, and private vehicle
photo storage. No server-side Flutter process or custom backend is required.

The repository does not contain a production URL until Cloudflare creates the
Pages project and a deployment succeeds. Do not replace the placeholder status
in this document with a guessed URL.

## Architecture and security boundary

- Cloudflare Pages serves the generated `build/web` files over HTTPS.
- GitHub Actions installs Flutter `3.47.7`, runs the quality gates, builds the
  release, verifies the output, and uploads it with Wrangler.
- The browser receives only `SUPABASE_URL` and
  `SUPABASE_PUBLISHABLE_KEY`. Flutter embeds these compile-time values in the
  public browser bundle because the Supabase publishable key is designed for
  public clients.
- Authentication, PostgreSQL grants/RLS, and the private
  `vehicle-photos` Storage policies remain the authorization boundary.
- The Cloudflare token, account ID, GitHub credentials, passwords, and any
  Supabase secret/service-role key must remain in secret stores and must never
  be placed in Dart, JavaScript, generated assets, or documentation.
- OCR remains browser-local. Vehicle images are not uploaded to a third-party
  OCR service.

## GitHub Actions configuration

The workflow is `.github/workflows/deploy-pages.yml`. It runs only for pushes
to `main` or an intentional `workflow_dispatch`; preview deployments are not
enabled because a separate staging Supabase project is not configured.

Configure these GitHub Actions repository secrets before enabling a production
push:

| Secret | Purpose |
| --- | --- |
| `SUPABASE_URL` | Existing Supabase project URL |
| `SUPABASE_PUBLISHABLE_KEY` | Existing project publishable/anon key for browser use |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare account containing the Pages project |
| `CLOUDFLARE_API_TOKEN` | Scoped Cloudflare API token with Pages Edit permission |

Use the Supabase **publishable** key, or the legacy low-privilege `anon` key
where the project has not migrated. Never use a `sb_secret_*`,
`service_role`, or database credential. Do not paste any secret into an issue,
commit, chat message, or workflow log.

The action uses:

```text
Flutter: 3.47.7 stable
Build: flutter build web --release
Output: build/web
Pages project: parking-management
```

The build validates formatting, analysis, tests, the OCR bridge syntax, the
required OCR assets, lazy runtime loading, and a credential-shaped-value scan
before invoking Wrangler. The generated Supabase values are intentionally
public client configuration; the workflow still keeps them in GitHub secret
settings to avoid accidental logging and to make environment changes
controlled.

## First-time Cloudflare setup

1. Sign in to Cloudflare and open **Workers & Pages**.
2. Create a Pages project named `parking-management` using the Direct Upload
   path. Keep the project on the free plan and do not add a custom domain.
3. Create a custom Cloudflare API token with Account -> Cloudflare Pages ->
   Edit permission. Store it only as `CLOUDFLARE_API_TOKEN`.
4. Copy the Cloudflare account ID into
   `CLOUDFLARE_ACCOUNT_ID`. Do not put either value in the repository.
5. Add the two Supabase public configuration values as the corresponding
   GitHub Actions secrets.
6. Review the workflow and trigger it from the GitHub Actions tab with
   `workflow_dispatch`, or push an approved change to `main`.
7. Record the actual URL printed by Wrangler and shown in the Cloudflare
   deployment. The URL must be tested before it is documented as production.

Cloudflare's current Pages build image does not list Flutter. That is why this
repository builds in GitHub Actions and sends the already-built static
directory to Pages instead of asking Pages to install an SDK on every build.

## Supabase production configuration

Before live testing:

1. Review the source-controlled migration
   `supabase/migrations/20261014160000_create_parking_sessions_security.sql`.
2. Apply it to the intended Supabase project through the approved Supabase
   workflow. Do not reset the project or run an unreviewed migration.
3. Confirm `parking_sessions` has RLS enabled and the
   `vehicle-photos` bucket is private.
4. Confirm the owner-only table and Storage policies remain unchanged.
5. Create the administrator-managed email/password test user. Public
   registration is not part of this app.
6. In Supabase Auth URL Configuration, set the Site URL to the actual
   `https://<actual-project>.pages.dev/` URL after it exists. Add the exact
   production origin and any intentionally supported local URL to the allowed
   redirect list. This app currently uses password sign-in rather than an
   OAuth callback, but the URL configuration still matters for Auth email
   links and future password-reset behavior.
7. Use two separate test accounts for RLS and private-photo checks where
   possible. Do not use the privileged SQL Editor as proof of browser RLS.

The frontend deployment alone does not prove hosted RLS or Storage isolation.
User A must not be able to read, update, delete, sign, or replace User B's
sessions or photos, including when IDs and paths are guessed.

## PWA, SPA, and cache behavior

`web/manifest.json` contains the application name, short name, icons, theme
color, background color, standalone display, and portrait preference.
Cloudflare receives `index.html` at the output root. The app currently uses
Flutter navigation inside one document rather than server-side named routes,
so no Pages Function or catch-all rewrite is required. Verify root refresh and
browser back/forward behavior against the real URL before adding redirects.

`web/_headers` applies:

- long-lived immutable caching only to versioned `/ocr-v1/*` assets;
- `X-Content-Type-Options: nosniff`;
- `Referrer-Policy: strict-origin-when-cross-origin`.

It does not make Supabase responses, signed URLs, or private photos public or
cacheable. If Flutter stops copying `_headers` into `build/web`, configure the
equivalent Pages rule in the dashboard instead and verify the resulting
headers with `curl -I`.

The OCR bridge loads `tesseract.min.js`, the worker, the compatible core, and
the English model only when OCR is requested. The checked-in OCR inventory is
approximately 31.4 MB; the measured local first-use request set was
approximately 15.0 MB uncompressed. Repeat-use caching and compressed
production transfer must be measured on the deployed host.

## Local release validation

From PowerShell, set the public values only in the current process:

```powershell
$env:SUPABASE_URL = "https://your-project-ref.supabase.co"
$env:SUPABASE_PUBLISHABLE_KEY = "sb_publishable_..."

dart format .
flutter analyze
flutter test
flutter build web --release `
  --dart-define=SUPABASE_URL=$env:SUPABASE_URL `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=$env:SUPABASE_PUBLISHABLE_KEY
node --check web/parking_ocr.js
git diff --check
```

Inspect `build/web` for the manifest, icons, OCR runtime/worker/model files,
and absence of service-role keys, secret keys, database passwords, access
tokens, or local configuration files. Never commit `build/` or `.env`.

## Live verification checklist

Record each item as **Passed**, **Failed**, **Blocked**, **Not tested**, or
**Not applicable**. Do not infer production behavior from local widget tests.

- HTTPS URL loads in Chrome and Edge without uncaught JavaScript errors.
- Sign-in, invalid credentials, session persistence, and sign-out work.
- New entry validation, duration calculation, expiry boundary, save with and
  without a photo, private photo upload, and photo retrieval work.
- Dashboard, search, history, detail, edit, delete, refresh, and navigation
  work.
- OCR assets are absent at startup, load on request, show progress, and leave
  manual entry available after no-text, timeout, cancellation, or failure.
- Browser network inspection shows OCR requests are same-origin and photos/
  Supabase calls go only to the configured Supabase project.
- Android Chrome camera, OCR, manual correction, save/photo flow, responsive
  layout, installation, refresh, and reopening work where the device is
  available.
- iPhone Safari camera, OCR, manual correction, save/photo flow, responsive
  layout, Add to Home Screen, standalone launch, refresh, and navigation work
  where the device is available.
- Two-account RLS and private Storage isolation are verified without sharing
  credentials.
- `curl -I` confirms HTTPS, expected MIME types, OCR cache headers, and no
  public-cache rule for private Supabase resources.

## Rollback and recovery

Frontend rollback must not alter Supabase data:

1. Identify the last known-good Cloudflare Pages deployment in the project's
   deployment history.
2. Use Cloudflare's supported deployment rollback/retry action to restore that
   static deployment, or run the workflow from the known-good Git commit.
3. If the source is wrong, create a normal Git revert commit and let the
   approved `main` workflow build the correction. Never force-push.
4. If configuration is wrong, correct the GitHub secret or Cloudflare
   setting, rerun the workflow, and compare the resulting URL/assets.
5. If Auth redirects fail, restore the previous exact Site URL/redirect list
   while preserving the database and Storage policies.
6. If OCR assets fail, check the deployed `/ocr-v1/` paths, MIME responses,
   cache headers, and base URL before changing code. Manual plate entry must
   remain available.

Do not reset the Supabase project, delete users, delete Storage objects, or
run destructive SQL as part of a frontend rollback.

## Cost and limitations

The target is Cloudflare Pages' free plan and the existing Supabase free-tier
project. This is a cost target, not a guarantee of unlimited usage, uptime,
storage, database capacity, or account availability. Cloudflare Pages limits
build concurrency, monthly builds, site files, and per-file size; Supabase
limits and pause behavior can change. Check the current official
[Cloudflare Pages limits](https://developers.cloudflare.com/pages/platform/limits/)
and [Supabase pricing](https://supabase.com/pricing) before production use.

The app still requires internet access for Supabase operations, does not
provide an offline photo queue, and cannot promise identical camera,
WebAssembly, OCR memory, or PWA installation behavior across browsers.

## Current handover status

As of the repository inspection for Phase 9:

- Local Phase 4-8 code is committed and pushed.
- Local release, analysis, test, OCR, and static security checks have passed.
- No Cloudflare Pages project or production URL has been verified by this
  session.
- Hosted Supabase migration/Auth/RLS/Storage behavior is not yet verified.
- Android/iPhone production/PWA checks are not yet verified.
