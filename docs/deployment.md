# Production deployment and handover

The production target is a static Flutter Web release on Cloudflare Pages
using the free `pages.dev` hostname and the selected project name
`parking`. The expected production hostname is
`https://parking-85u.pages.dev/`. The application continues to use Supabase
for authentication, PostgreSQL, and private vehicle photo storage.

The latest production frontend was deployed from commit `f958c26` by GitHub
Actions run `39551201127` on 2026-10-21. All workflow steps, including the
Cloudflare Pages deployment, succeeded. The deployed root returned the
application title `Parking Management`.

The approved Supabase migrations
`20261024100000_tenant_member_limits_permissions.sql` and
`20261024110000_fix_device_session_email_return_types.sql` are applied to the
verified `parking-management` project, and the remote migration history
matches. The follow-up replaces three RPC definitions with explicit
`auth.users.email::text` casts; it does not transform or delete data. A
post-application schema-lint attempt could not authenticate to PostgreSQL:
the CLI reported a password failure for its temporary login role, and
`SUPABASE_DB_PASSWORD` was absent from the process environment. The corrected
RPCs therefore remain unverified by a post-migration lint run. The hosted
Custom Access Token Hook configuration and Vault were not changed or verified
during this rollout. Edge Function deployment status was not checked as part
of this release.

## Architecture and security boundary

- Cloudflare Pages serves the generated `build/web` files over HTTPS.
- GitHub Actions installs Flutter `3.47.7`, runs the quality gates, builds the
  release, verifies the output, and uploads it with Wrangler.
- The browser receives public compile-time configuration: `SUPABASE_URL`,
  and `SUPABASE_PUBLISHABLE_KEY`. Flutter embeds these values in the public
  browser bundle.
- The local PostgreSQL API described in
  [Local PostgreSQL development](local-development.md) is an opt-in,
  loopback-only development aid. The production workflow does not set
  `PARKING_BACKEND=local`, does not deploy that API, and continues to build
  the Supabase backend path.
- Authentication, tenant membership, PostgreSQL grants/RLS, and private
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

1. Review all source-controlled migrations:
   `supabase/migrations/20261014160000_create_parking_sessions_security.sql`
   `supabase/migrations/20261018185121_tenant_administration.sql`, and all
   subsequent timestamped migrations through
   `supabase/migrations/20261024110000_fix_device_session_email_return_types.sql`.
2. Apply any pending migrations to the intended Supabase project through the
   approved Supabase workflow. Do not reset the project or run an unreviewed
   migration.
3. Deploy `create-tenant-owner` and
   `complete-temporary-password-reset` with the Supabase CLI. Keep JWT
   verification enabled and do not disable it to resolve authentication
   errors.
4. Confirm `parking_sessions`, `tenants`, and `tenant_memberships` have RLS
   enabled and the `vehicle-photos` bucket is private.
5. Create or verify the private Auth account for
   `dieselpetrol6@gmail.com`, then review and run
   `supabase/operations/provision_initial_super_admin.sql`.
6. Sign out and back in. Verify the Admin destination appears only for the
   database-provisioned role. Create a tenant using an existing Auth account
   as the owner, then create a tenant with a new email and verify the
   temporary-password reset gate before tenant management and parking
   operations.
7. Use separate accounts to verify that one tenant cannot read or modify
   another tenant's records/photos and the Super Admin can access both.
8. In **Authentication -> URL Configuration**, set **Site URL** to the
   production origin `https://parking-85u.pages.dev/`. Add that same exact
   origin to **Redirect URLs**. The self-service "Forgot password" flow
   (`docs/security.md`) calls `resetPasswordForEmail(email, redirectTo:
   '${Uri.base.origin}/')`, so the recovery link always redirects to the
   current page's own root rather than a fixed path; no Cloudflare
   `_redirects`/SPA-fallback rule is required. If local development also needs
   to receive recovery emails, add that exact local origin (for example
   `http://localhost:PORT/`) as a second entry in Redirect URLs. Do not add a
   broad wildcard URL.
9. Do not use the privileged SQL Editor as proof of browser RLS.
10. The `send-email` Edge Function (Supabase Auth "Send Email" hook) and its
    migration (`20261021110000_password_reset_rate_limit.sql`) have been
    deployed/applied to the hosted project via the Supabase CLI:
    `supabase functions deploy send-email --no-verify-jwt`,
    `supabase secrets set BREVO_API_KEY=... EMAIL_SENDER_ADDRESS=...
    EMAIL_SENDER_NAME=... SEND_EMAIL_HOOK_SECRET=...`, and
    `supabase config push` (with `SEND_EMAIL_HOOK_SECRET` set in the same
    shell so the `env(SEND_EMAIL_HOOK_SECRET)` reference in
    `supabase/config.toml` resolves). No Dashboard interaction was required
    or used; none of these secret values are committed, logged, or present
    in Dart/browser code. See `docs/security.md` for the full architecture
    and the 6-recovery-emails-per-account-per-day application-level cap.
11. The device-session and tenant-member migrations through
    `20261024110000_fix_device_session_email_return_types.sql` are applied to
    the verified production project. Migration history is in sync. The
    post-application schema lint is blocked on valid database authentication;
    the production Custom Access Token Hook configuration was not changed or
    verified by this rollout. See
    `docs/device-session-limits.md` and
    `docs/tenant-member-management.md` for validation details.

The frontend deployment alone does not prove hosted RLS or Storage isolation.
Tenant A members must not be able to read, update, delete, sign, or replace
Tenant B's sessions or photos, including when IDs and paths are guessed.

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

## Live static deployment verification

On 2026-10-18, unauthenticated GET requests to the production hostname
`https://parking-85u.pages.dev/` returned HTTP 200 for:

- `/`
- `/manifest.json`
- `/flutter_bootstrap.js`
- `/flutter.js`
- `/main.dart.js`
- `/icons/Icon-192.png`
- `/icons/Icon-512.png`

The root response included the configured
`X-Content-Type-Options: nosniff` and
`Referrer-Policy: strict-origin-when-cross-origin` headers. These responses
show that the sampled static files are served; they do not establish that
sign-in, parking CRUD, Supabase RLS, private Storage, camera, or mobile/PWA
flows work. Recheck all relevant behavior after any new deployment.

After commit `f958c26`, GitHub Actions run `39551201127` completed all 14
workflow steps successfully, including Flutter formatting, analysis, tests,
release build, output checks, Cloudflare configuration validation, and
deployment. A fresh GET of the production root returned `Parking Management`.

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

As of the 2026-10-24 migration review:

- Commit `f958c26` is pushed to `main`; GitHub Actions run `39551201127`
  succeeded and the production root serves the Parking Management app.
- Supabase migrations through
  `20261024110000_fix_device_session_email_return_types.sql` are recorded as
  applied to `parking-management`. Read-only verification confirmed the
  member-limit/permission schema, audit table, permission RPC, and RLS
  policies; migration history is in sync.
- The post-migration `supabase db lint --linked --schema public` attempt
  failed before schema inspection because database authentication failed for
  the CLI's temporary login role. `SUPABASE_DB_PASSWORD` was not set in the
  process environment, so post-fix lint confirmation remains outstanding.
- pgTAP and PostgreSQL concurrency tests remain unexecuted because local
  Supabase/Docker is unavailable. The local API integration test is blocked
  by the old `parking_local` schema and unavailable local owner password.
- Hosted Auth Hook activation, Edge Function status, two-account RLS/Storage
  behavior, and Android/iPhone production/PWA behavior were not verified.
