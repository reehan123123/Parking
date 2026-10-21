# Parking SaaS and Performance Progress

- **Updated:** 2026-10-24
- **Branch:** `main`
- **Baseline commit:** `a3faec0`

## Completed

- [x] Preserve authenticated access while adding tenant-scoped authorization.
- [x] Add bounded, stable, server-side session pagination.
- [x] Bound the Dashboard preview and add a path to full History.
- [x] Use parallel exact, tenant-scoped `HEAD` counts for active and expired
      sessions.
- [x] Avoid repeating summary counts for search-only changes.
- [x] Prevent duplicate list refreshes when details already notified the
      parent of a data change.
- [x] Add repository HTTP-mock and Dashboard/History regression coverage.
- [x] Update performance baseline, decisions, checkpoints, and deployment
      handover documentation.
- [x] Run formatting, analysis, the full Flutter test suite, and a release
      web build.
- [x] Inspect the local release inventory, check for retired OCR runtime
      assets, and scan for credential patterns. Live static-host checks are
      historical and do not verify the current local changes.
- [x] Confirm the final diff has no whitespace errors.

## Tenant administration

- [x] Add tenant workspaces, memberships, a database-backed Super Admin role,
      and a role-gated Admin screen with tenant creation.
- [x] Add tenant rename, reversible archive/restore, and existing-user
      membership management while preserving parking records and photos.
- [x] Allow a Super Admin in All Tenants mode to create an entry after
      selecting an active tenant.
- [x] Scope parking reads, counts, writes, and private-photo authorization to
      the selected tenant while preserving existing session and photo paths.
- [x] Prepare the migration/backfill and one-time initial Super Admin
      provisioning operation.
- [x] Update the product, Supabase, security, deployment, entry, and session
      management documentation.
- [ ] Apply the tenant migrations and provision the initial Super Admin in
      Supabase. The user plans to apply these through the SQL Editor.

## Initial tenant-foundation validation

- `dart format .` — passed; 56 Dart files checked, none changed.
- `flutter analyze` — passed with no issues.
- `flutter test` — passed; 108 tests.
- `flutter build web --release` — passed. Flutter emitted a non-fatal
  Cupertino icon-font warning; the release was produced.
- `git diff --check` — passed.
- Release output — 39 files, 42,502,052 bytes (about 40.53 MiB); no
  OCR-specific assets or OCR runtime references were found.
- Credential-shaped-value scans — no matches for service-role-style keys,
  JWTs, or database connection credentials.
- SQL test prerequisites — Supabase CLI, Docker, and `psql` are unavailable.
  The tenant, tenant-management, and private-photo pgTAP tests were reviewed
  but not executed.
- Hosted validation — the local app uses public configuration from ignored
  `.env.local`; sign-in reaches Supabase but tenant access reports missing
  setup. No privileged database access is available here. Hosted migrations,
  role provisioning, tenant isolation, and private-photo behavior remain
  unverified pending the user's SQL Editor action.
- Deployment — commit `5e2ace7` was pushed to `main`; GitHub Actions run
  `39209169654` succeeded. The expanded tenant-management follow-up remains
  local at the time of this foundation validation.

## Tenant-management follow-up validation

- `dart format .` — passed; 56 files checked, none changed.
- `flutter analyze` — passed with no issues.
- `flutter test` — passed; 118 tests.
- `flutter build web --release` — passed; 39 release files, about 40.56 MiB.
- `git diff --check` — passed.
- Release output and app source contain no OCR-only filenames, runtime, or
  bridge references.
- Tenant-management pgTAP SQL was reviewed but not executed; Supabase CLI,
  Docker, and `psql` are unavailable.
- The local release was built without production Supabase compile-time
  values. Authenticated, hosted RLS/Storage, and physical-device behavior
  remain unverified.

## Performance-hardening validation before tenant changes

- `dart format .` — passed; 48 files checked, none changed.
- `flutter analyze` — passed with no issues.
- `flutter test` — passed; 96 tests.
- `flutter build web --release` — passed. Flutter printed a non-fatal warning
  that the Cupertino icon font was expected but only Material Icons were
  found.
- Local release output — 39 files, 42,450,799 bytes; no OCR-named assets or
  OCR runtime identifiers found.
- Live static checks — HTTP 200 for the root, manifest, Flutter bootstrap,
  Flutter loader, Dart bundle, and 192/512 app icons.
- Credential-pattern scan — no valid credentials found. The initial
  case-insensitive AWS-pattern hit was a lowercase generated bundle
  substring, not a valid AWS access-key identifier.
- `git diff --check` — passed.

## Not verified / blocked

- Authenticated Supabase list/count behavior, hosted RLS, and query plans:
  no configured non-production project or test accounts were available.
- Representative database latency and large-table performance: not measured.
- Two-user private-photo and ownership isolation: not tested against a hosted
  project.
- Real camera, photo upload, Android/iPhone layout, mobile performance, and
  PWA installation/resume behavior: not performed.
- The local release build did not include production Supabase compile-time
  values; it verifies the artifact build, not live application connectivity.

## Change and deployment status

Commit `5e2ace7` is pushed to `main`, and GitHub Actions run `39209169654`
succeeded. The tenant-management follow-up is uncommitted and has not been
pushed or deployed. No hosted migration or production data change was
performed. The deployed frontend still needs the tenant schema and initial
Super Admin provisioning before end-to-end tenant access can work.

The next product validation step is to apply the reviewed migration in a
non-production Supabase project, provision test roles, and execute the RLS and
Storage tests with separate accounts. After that, measure authenticated query
behavior with representative data and query plans; consider keyset pagination
or further optimization only if those measurements demonstrate a need.

## Tenant-owner onboarding follow-up

- [x] Preserve existing Auth passwords when assigning an existing user.
- [x] Add server-side creation for missing owner accounts behind JWT and
      database-backed Super Admin authorization.
- [x] Show a generated temporary password once to the authorized Super Admin
      and require the new owner to change it before accessing tenant data.
- [x] Add an idempotent tenant-creation request ledger and retry handling.
- [x] Update the workflow, security, Supabase, deployment, README, and
      implementation decision/checkpoint documentation.

Local validation:

- `dart format .` — passed; 57 Dart files checked, none changed.
- `flutter analyze` — passed with no issues.
- `flutter test` — passed; 122 tests.
- `flutter build web --release` — passed. Flutter emitted its existing
  non-fatal Cupertino icon-font and Wasm dry-run warnings.
- Node's experimental TypeScript syntax parser accepted all three Edge
  Function files; this does not substitute for Deno/SDK type-checking.
- `git diff --check` — passed.

Deno/SDK type-checking and Edge Function runtime checks remain unverified
because Deno is unavailable. The onboarding pgTAP test remains unexecuted
because Docker and `psql` are unavailable. The Supabase CLI is installed, but
the migration was not applied and the functions were not deployed. Hosted
account creation, RLS behavior, and Super Admin end-to-end access therefore
remain unverified. The worktree is uncommitted; no push or deployment was
performed.

## Tenant member limits and parking-entry permissions

- [x] Add the database-backed tenant member limit (default 1, maximum 50),
      preserving existing memberships and excluding owners from usage.
- [x] Enforce member capacity atomically in PostgreSQL and mirror the policy
      in the loopback-only local API.
- [x] Add independent View/Add/Edit/Delete membership permissions with
      server-side parking-session and private-photo authorization.
- [x] Add owner Manage Members settings, Super Admin tenant/member controls,
      capacity reporting, audit history, and existing device-policy reuse.
- [x] Add English/Hindi strings, repository/widget/API/pgTAP/concurrency
      coverage, and member-management/security documentation.
- [x] Update local PostgreSQL initialization and migration tooling to apply
      the local member schema and refresh the least-privilege API role grants.

Local validation:

- `dart format .` — passed; 92 Dart files checked, 3 formatted.
- `flutter analyze` — passed with no issues.
- `flutter test` — passed; 177 tests.
- `flutter build web --release` — passed. Flutter emitted the existing
  non-fatal Cupertino icon-font warning and Wasm dry-run notice.
- `npm --prefix local-api test` — passed; 4 security tests.
- `node --check` — passed for the local API server and integration/concurrency
  tests. PowerShell migration scripts parsed successfully.
- `git diff --check` — passed.

Local database verification remains blocked. `supabase db push --dry-run
--local` and `supabase test db --local` could not connect to
`127.0.0.1:54322`; Docker is unavailable. The PostgreSQL concurrency tests
were skipped because their local Supabase URLs were not configured. The local
API integration test returned 500 because the existing `parking_local`
database lacks the new member columns. Applying migration 003 as the runtime
`parking_api` role was denied because that role does not own the tables; the
documented local-owner migration path requires the local admin password,
which was not available. The audit-trail wiki could not be updated because
`LLMWIKI_ROOT` is not configured.

## Production rollout and device-session RPC correction

- Applied `20261024100000_tenant_member_limits_permissions.sql` to the
  verified `parking-management` project after explicit approval. Remote
  migration history now matches through this version; read-only checks
  confirmed the member-limit/permission columns, audit table, RPC, and RLS
  policies. No tenant, membership, parking-session, or payment rows were
  deleted.
- Commit `f958c26` was pushed to `main`; GitHub Actions run `39551201127`
  passed all workflow steps and deployed to Cloudflare Pages. A fresh root
  request returned `Parking Management`.
- The production `supabase db lint --linked --schema public` found three
  return-type errors in device-session list RPCs. Auth email is
  `character varying`, while the functions declare `text`; this is a schema
  contract mismatch, not bad user data or project configuration. A prior
  migration fixed the same issue in `list_tenant_members` by casting the
  email to `text`.
- Added the forward migration
  `20261024110000_fix_device_session_email_return_types.sql` and a pgTAP
  regression assertion for `list_tenant_device_sessions`. The linked
  dry-run previews only that migration when run with a temporary,
  format-valid `SEND_EMAIL_HOOK_SECRET` and `--skip-vault`. A plain CLI
  invocation is rejected by local Auth Hook config validation; no config or
  hosted Vault value was changed.
- After separate explicit approval, applied
  `20261024110000_fix_device_session_email_return_types.sql` to
  `parking-management` using `supabase db push --linked --skip-vault --yes`.
  The CLI reported success, and `supabase migration list --linked` confirms
  local/remote history is in sync through `20261024110000`. The migration
  only replaces three function definitions and does not mutate rows.
- Post-application `supabase db lint --linked --schema public` passed with
  “No schema errors found,” confirming the three reported return-type errors
  are resolved.
- Commits `c1288cc` (RPC correction) and `cef628d` (rollout documentation)
  were pushed to `main`. GitHub Actions run `39561743168` passed all 14
  workflow steps and deployed to Cloudflare Pages; the production root
  returned HTTP 200 with the expected app title.
- Security advisors report generic authenticated `SECURITY DEFINER` RPC
  warnings for the existing authorization-checked API pattern, plus the
  existing disabled leaked-password-protection setting. These were not
  changed in this rollout. pgTAP and migrated local API integration tests
  remain blocked by unavailable Docker/local database-owner access.
