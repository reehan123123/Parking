# Production deployment and handover

The production target is a static Flutter Web release on Cloudflare Pages
using the free `pages.dev` hostname and the selected project name
`parking`. The expected production hostname is
`https://parking-85u.pages.dev/`. The application continues to use Supabase
for authentication, PostgreSQL, and private vehicle photo storage.

The Pages project exists, but the last observed deployment served HTTP 404 for
the root and expected Flutter assets. Treat production as unverified until a
GitHub Actions deployment uploads `build/web` and the live asset checks pass.

## Architecture and security boundary

- Cloudflare Pages serves the generated `build/web` files over HTTPS.
- GitHub Actions installs Flutter `3.47.7`, runs the quality gates, builds the
  release, verifies the output, and uploads it with Wrangler.
- The browser receives public compile-time configuration: `SUPABASE_URL`,
  and `SUPABASE_PUBLISHABLE_KEY`. Flutter embeds these values in the public
  browser bundle.
- Authentication, PostgreSQL grants/RLS, and the private
  `vehicle-photos` Storage policies remain the authorization boundary.
- The Cloudflare token, account ID, GitHub credentials, passwords, and any
  Supabase secret/service-role key must remain in secret stores and must never
  be placed in Dart, JavaScript, generated assets, or documentation.

## GitHub Actions configuration

The workflow is `.github/workflows/deploy-pages.yml`. It runs only for pushes
to `main` or an intentional `workflow_dispatch`, and it uses the protected
GitHub environment named `production`. Preview deployments are not enabled
because a separate staging Supabase project is not configured.

Configure these secrets in the GitHub **production environment** before
running the workflow:

| Secret | Purpose |
| --- | --- |
| `SUPABASE_URL` | Existing Supabase project URL |
| `SUPABASE_PUBLISHABLE_KEY` | Existing project publishable/anon key for browser use |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare account containing the Pages project |
| `CLOUDFLARE_API_TOKEN` | Scoped Cloudflare API token with Pages Edit permission |

Require an environment reviewer if the repository's protection settings
support it. The account ID is configuration rather than a credential, but it
is kept in the protected environment with the token to prevent account drift.

Use the Supabase **publishable** key, or the legacy low-privilege `anon` key
where the project has not migrated. Never use a `sb_secret_*`,
`service_role`, or database credential. Do not paste any secret into an issue,
commit, chat message, or workflow log.

The action uses:

```text
Flutter: 3.47.7 stable
Build: flutter build web --release
Output: build/web
Pages project: parking
Production hostname: https://parking-85u.pages.dev/
Wrangler: 4.151.0
```

The build validates formatting, analysis, tests, every required non-empty
Flutter/PWA release asset, and a credential-shaped-value scan before invoking
Wrangler. The generated Supabase
values are intentionally public client configuration; the workflow still keeps
them in protected GitHub environment secrets to avoid accidental logging and
to make environment changes controlled. The workflow records Wrangler's
deployment URL and Pages alias URL in the GitHub Actions summary.

## First-time Cloudflare setup

1. Sign in to Cloudflare and open **Workers & Pages**.
2. Open the existing Pages project named `parking`. Keep it on the free plan
   and do not add a custom domain.
3. Create a custom Cloudflare API token with Account -> Cloudflare Pages ->
   Edit permission. Store it only as `CLOUDFLARE_API_TOKEN`.
4. Copy the Cloudflare account ID into
   `CLOUDFLARE_ACCOUNT_ID`. Do not put either value in the repository.
5. Add the two Supabase public configuration values to the corresponding
   GitHub `production` environment secrets.
6. Review the workflow and trigger it from the GitHub Actions tab with
   `workflow_dispatch`, or push an approved change to `main`. The workflow
   deploys `build/web` with:

   ```text
   pages deploy build/web --project-name=parking
   ```

   Do not add `--branch=main`; that option is for an explicit Pages preview
   branch, while this workflow is the production deployment from `main`.
7. Record the actual Wrangler deployment URL and Pages alias URL from the
   workflow summary. Test the root, Flutter bootstrap files, manifest, and
   icons before treating the hostname as production.

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

- `X-Content-Type-Options: nosniff`;
- `Referrer-Policy: strict-origin-when-cross-origin`.

It does not make Supabase responses, signed URLs, or private photos public or
cacheable. If Flutter stops copying `_headers` into `build/web`, configure the
equivalent Pages rule in the dashboard instead and verify the resulting
headers with `curl -I`.

## Current 404 diagnosis

The Cloudflare project `parking` has a successful deployment record, but the
last observed production and deployment-specific URLs returned 404 for
`index.html`, `main.dart.js`, `flutter.js`, and `manifest.json`. The
corresponding GitHub Actions run stopped before the release build because
`SUPABASE_URL` was not configured, so it could not have uploaded the Flutter
output. The corrected workflow now targets `parking`, removes the preview
branch flag, and verifies the generated `build/web` directory before
uploading it. Do not accept a deployment until those checks pass against the
live hostname.

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
git diff --check
```

Inspect `build/web` for the manifest and icons, and verify the absence of
service-role keys, secret keys, database passwords, access tokens, or local
configuration files. Never commit `build/` or `.env`.

## Live verification checklist

Record each item as **Passed**, **Failed**, **Blocked**, **Not tested**, or
**Not applicable**. Do not infer production behavior from local widget tests.

- HTTPS URL loads in Chrome and Edge without uncaught JavaScript errors.
- Sign-in, invalid credentials, session persistence, and sign-out work.
- New entry validation, duration calculation, expiry boundary, save with and
  without a photo, private photo upload, and photo retrieval work.
- Dashboard, search, history, detail, edit, delete, refresh, and navigation
  work.
- Browser network inspection shows photos and Supabase calls go only to the
  configured Supabase project.
- Android Chrome camera, manual registration, save/photo flow, responsive
  layout, installation, refresh, and reopening work where the device is
  available.
- iPhone Safari camera, manual registration, save/photo flow, responsive
  layout, Add to Home Screen, standalone launch, refresh, and navigation work
  where the device is available.
- Two-account RLS and private Storage isolation are verified without sharing
  credentials.
- `curl -I` confirms HTTPS, expected MIME types, and no public-cache rule for
  private Supabase resources.

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
or PWA installation behavior across browsers.

## Current handover status

As of the repository inspection for Phase 9:

- Local Phase 4-8 code is committed and pushed.
- Local release, analysis, test, and static security checks have passed.
- Cloudflare Pages project `parking` exists at the expected hostname, but the
  last observed deployment served 404 responses for the Flutter shell and
  assets.
- The corrected GitHub Actions workflow is ready to build `3.47.7`, verify
  `build/web`, and deploy the production upload after the protected
  environment secrets are configured.
- Hosted Supabase migration/Auth/RLS/Storage behavior is not yet verified.
- Android/iPhone production/PWA checks are not yet verified.
