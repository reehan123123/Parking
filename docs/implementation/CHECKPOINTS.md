# Performance Hardening Checkpoints

## 2026-10-18 — Scope and baseline

- Read the copied `PERFORMANCE_PLAN.md` and inspected the owner-scoped
  application, repository, tests, deployment notes, and Git baseline.
- Preserved the existing data and security architecture; deferred
  multi-tenant, billing, payment, location, reporting, and export features.
- Recorded the pre-change release inventory and code-derived Dashboard and
  History request behavior.

## 2026-10-18 — Bounded reads and summary counts

- Added server-side range pagination with a 10-session Dashboard preview and
  50-session History pages, a 100-row page-size ceiling, a sentinel row, and
  stable `entry_time DESC, id DESC` ordering.
- Replaced full expiry-timestamp transfer with two parallel, owner-filtered
  exact `HEAD` counts using the same UTC cutoff.
- Kept summary requests out of search-only updates and retained explicit,
  lifecycle, and data-change refreshes.
- Added PostgREST request-level coverage and widget tests for pagination,
  search, retries, stale responses, and parent/child refresh coordination.

## 2026-10-18 — Verification and handoff

- The focused Dashboard and History parent-refresh regression tests passed
  after the final refresh-coordination adjustment.
- `flutter analyze` passed; the complete Flutter suite passed with 96 tests.
- `flutter build web --release` passed. Artifact inventory, OCR-asset
  absence, credential-pattern review, and static-host checks were completed.
- Remaining hosted Supabase, real-device, and authenticated performance
  checks are documented in `PERFORMANCE_BASELINE.md` and `PROGRESS.md`.

The session checkpoint `022-selecting-performance-hardening-scope.md`
contains the detailed scope, initial evidence, and blockers.

## 2026-10-18 — Tenant administration and Super Admin

- Corrected the scope after the user pointed out that the app lacked the
  expected Admin panel and tenant creation flow. The plan describes a
  multi-tenant SaaS product, while the inspected baseline was owner-scoped.
- Chose one personal workspace per existing Auth user for safe data backfill.
  Tenant members can access their assigned workspace; the database-backed
  Super Admin can access all tenant records and private photos.
- Tenant creation assigns an existing Supabase Auth account as owner. Creating
  Auth users/invitations remains a Supabase Dashboard operation; no
  service-role key or paid service is added.
- Added a separate SQL provisioning operation for
  `dieselpetrol6@gmail.com`. Neither it nor the tenant migration has been
  applied to the hosted database.
- Added tenant-aware app access, a role-gated Admin destination and tenant
  creation UI, tenant-scoped parking queries, and a more polished Dashboard.
- Hosted RLS/Storage tests, live Super Admin provisioning, and production
  behavior remain blocked until the migration is reviewed/applied and the
  account is confirmed in Supabase Auth.

## 2026-10-18 — Tenant UI verification and documentation alignment

- Updated the workflow specification, README, Supabase/security/deployment
  guides, and parking-entry/session-management documentation to describe the
  tenant membership and Super Admin model.
- Added widget regressions for tenant switching and mobile-width Admin
  rendering.
- Final local gates passed: formatting, analysis, all 108 Flutter tests,
  release build, and `git diff --check`.
- Release inspection found 39 files totaling 42,502,052 bytes and no
  OCR-specific assets/runtime references or credential-shaped values.
- Supabase CLI, Docker, `psql`, and public Supabase build configuration are
  unavailable here. Hosted migration/RLS/Storage verification and initial
  Super Admin provisioning remain unperformed; no commit, push, or deployment
  was made.

## Tenant-owner onboarding follow-up

- Chose to preserve existing Auth passwords and create a missing owner account
  only in a JWT-authenticated Edge Function after a database-backed Super
  Admin check.
- New owners receive a one-time, cryptographically generated temporary
  password. A first-sign-in gate and database authorization helpers block
  tenant data until the owner changes it.
- Added an idempotent tenant-creation request ledger so retrying after a
  partial failure does not create duplicate workspaces.
- Local validation passed: formatting, analysis, all 122 Flutter tests, the
  release web build, a Node TypeScript syntax parse of all three Edge
  Function files, and `git diff --check`.
- The Supabase CLI 2.121.0 is installed, but Deno, Docker, and `psql` are not.
  Deno/SDK type-checking, Edge Function runtime checks, and pgTAP migration
  tests have not been run. No hosted migration, function deployment, commit,
  or push was performed.

## 2026-10-19 — Super Admin rollout and tenant management

- Pushed tenant-creation foundation commit `5e2ace7` to `main`. GitHub Actions
  run `39209169654` completed successfully; static deployment returned HTTP
  200.
- The local sign-in error is caused by missing tenant schema in the configured
  Supabase project (or a project mismatch), not by stale browser assets. The
  user-provided Supabase dashboard screenshot shows only `parking_sessions`
  under `public`.
- The user selected reversible tenant archival. The follow-up adds tenant
  rename, archive/restore, member and role management for existing Auth users,
  last-owner protections, and a tenant chooser when adding a parking entry
  from All Tenants. Archival preserves sessions/photos and suspends member
  access.
- Follow-up migration:
  `supabase/migrations/20261019090000_tenant_management.sql`. It must run
  after `20261018185121_tenant_administration.sql`; then run
  `supabase/operations/provision_initial_super_admin.sql`.
- Supabase SQL Editor application and role provisioning remain pending. This
  environment has no privileged database credential or migration CLI.
- Follow-up local validation passed: formatting (56 files, no changes),
  analysis, all 118 Flutter tests, release web build, and `git diff --check`.
  The 39-file release contains no OCR-only asset names or runtime/bridge
  references.
- The tenant-management pgTAP test was reviewed but not executed because
  Supabase CLI, Docker, and `psql` are unavailable. No hosted migration,
  provisioning, RLS, or Storage check is claimed.

## 2026-10-20 — Tenant member controls and entry permissions

- Added member limits to the existing tenant model: one member by default,
  owners excluded, maximum 50. Capacity checks lock the tenant row so
  concurrent add/demote operations cannot consume the final slot twice.
- Added View/Add/Edit/Delete membership flags, preserving existing access and
  defaulting new members to View-only. PostgreSQL RLS and Storage helpers
  enforce the permissions; Flutter navigation and actions reflect them.
- Added owner Manage Members settings and member capacity/audit/permission
  controls to the existing Super Admin tenant manager. Device policy
  administration reuses the existing device-session implementation.
- Extended the local API and documented its schema migration. Local setup now
  applies ordered migrations; the existing-database migration helper refreshes
  runtime grants after DDL.
- Flutter validation passed: formatting, analysis, all 177 tests, and release
  web build. Local API security tests passed (4); JavaScript and PowerShell
  syntax checks and `git diff --check` passed.
- Database checks remain unverified: Supabase local DB is not running because
  Docker is unavailable, concurrency tests were skipped without local URLs,
  and the existing `parking_local` schema needs migration 003 via the local
  database owner. The runtime API role correctly lacks DDL ownership.
- No hosted migration, production data change, commit, push, or deployment
  occurred. `LLMWIKI_ROOT` is unset, so the personal audit wiki was not
  updated.

## 2026-10-24 — Production member rollout and RPC type correction

- Applied `20261024100000_tenant_member_limits_permissions.sql` to the
  verified `parking-management` project after explicit approval. Migration
  history and read-only checks confirmed the expected schema and RLS objects.
- Pushed commit `f958c26`; GitHub Actions run `39551201127` passed all steps
  and deployed the Flutter Web app to Cloudflare Pages. The production root
  returned the expected Parking Management title.
- Post-migration schema lint found three device-session RPC return-type
  errors: `auth.users.email` is `character varying`, but the functions declare
  `text`. This is the same class of mismatch fixed earlier for
  `list_tenant_members`, not a data/configuration issue.
- Prepared migration
  `20261024110000_fix_device_session_email_return_types.sql` and added a
  pgTAP assertion for the tenant device-session listing. Its linked dry-run
  previews only this file when the local `SEND_EMAIL_HOOK_SECRET` reference
  is satisfied and `--skip-vault` is passed. After separate explicit
  approval, the migration was applied to `parking-management` with Vault
  synchronization disabled. Linked migration history now matches through
  `20261024110000`.
- A post-application schema-lint attempt could not authenticate: PostgreSQL
  rejected the CLI temporary login role, and `SUPABASE_DB_PASSWORD` was
  absent. The corrected RPCs are not yet verified by post-migration lint.
- Local pgTAP/concurrency tests and the migrated local API integration test
  remain blocked by missing Docker/local Supabase and unavailable local
  database-owner credentials.
