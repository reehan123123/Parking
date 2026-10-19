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
