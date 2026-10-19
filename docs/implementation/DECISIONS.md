# Parking SaaS Implementation Decisions

- **Date:** 2026-10-18
- **Scope:** Tenant administration and performance hardening

## Add the missing tenant and Super Admin foundation

Inspection showed that the product plan described a multi-tenant SaaS
application, but the repository only isolated records by `created_by` and had
no tenant, membership, or admin model. The user clarified that tenant
creation and a global Super Admin panel are required. The implementation now
adds a database-backed `super_admins` table, tenant workspaces, memberships,
and a role-gated tenant administration screen.

- Each existing Auth user receives a `Personal workspace` and owner
  membership when the new migration is applied. Existing parking sessions are
  backfilled to that workspace without changing their owner, duration, or
  photo path.
- `parking_sessions` reads and writes are tenant-scoped in PostgreSQL RLS.
  Tenant members can access only workspaces they belong to; a Super Admin can
  access all tenants and their private photos.
- Tenant creation requires an existing Supabase Auth account as the tenant
  owner. No service-role key, browser-side privilege grant, invite service, or
  paid dependency is introduced.
- The requested initial Super Admin is provisioned with a separate SQL
  operation after migration and account creation. The migration and operation
  have not been applied to the hosted project.
- Billing, payment processing, location management, reporting, charts, CSV
  export, and member administration remain outside this implementation.

## Bound session reads

- Dashboard requests a 10-session preview.
- History requests 50 sessions per page.
- The repository rejects page sizes above 100 and requests one extra row to
  derive `hasMore`.
- List results use stable `entry_time DESC, id DESC` ordering.
- Offset pagination is retained for the tenant-scoped application.
  PostgreSQL RLS and tenant-membership checks authorize the rows before
  pagination. Keyset pagination is deferred until representative query plans
  or data volumes show that deep offsets need a different approach.
- Search, explicit refresh, and load-more preserve stale-response protection;
  search and refresh return to the first page.

## Count expiry states without transferring rows

The summary uses two parallel, exact PostgREST `HEAD` counts rather than
fetching all `expires_at` values into the client. Both requests filter by the
selected tenant when one is selected and retain the tenant RLS boundary.
The active predicate is `expires_at > asOf`; the expired predicate is
`expires_at <= asOf`. One UTC timestamp is passed to both requests.

This changes an initial Dashboard load from two requests to three: one
bounded list request plus two count requests. Search-only changes use one
list request and do not refresh the counts. Counts still refresh on initial
load, explicit refresh, app resume, and data changes. No latency improvement
is asserted without hosted measurements.

## Keep photos, auth, and duration behavior intact

The existing sign-in flow, photo capture and selection, private photo storage,
signed retrieval, upload/cleanup ordering, and duration/expiry rules are
preserved. Photo bytes are not loaded by either session list. A PostgreSQL
`create_tenant` function performs the guarded tenant-and-owner insert; no
runtime package, paid provider, cache, or external service is added.

The locked `http` package is declared for request-level tests only; no runtime
dependency was added or upgraded.

## Avoid duplicate list refreshes after details actions

Dashboard and History track data-change notifications sent while a details
route is open. When the parent refresh token or that notification changes,
the page skips the redundant reload after the route returns. This avoids
issuing a second list/summary request after the parent's refresh has started.
When no parent callback is provided, the page still refreshes locally.

## Deployment and operational boundary

The production static host was rechecked and the sampled shell, Flutter, and
PWA assets returned HTTP 200. This is not evidence of authenticated app,
Supabase, private photo, or mobile behavior. Tenant/admin code, migrations,
and performance changes remain local, uncommitted, and undeployed.

No hosted migration, data modification, commit, push, or deployment was
performed. Production tenant access cannot work until the migration is
reviewed and applied and the initial Super Admin operation is run.
