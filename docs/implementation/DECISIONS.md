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
- Super Admin tenant removal is reversible archival, not a hard delete.
  Archiving preserves parking rows and private photos, suspends member access,
  and supports restoration. Membership changes never delete Auth accounts or
  parking data, and a tenant must retain at least one owner.
- The requested initial Super Admin is provisioned with a separate SQL
  operation after migration and account creation. The migration and operation
  are a manual Supabase operation; their hosted status must be verified.
- Tenant membership management uses existing Auth accounts. Invitations and
  Auth-user creation remain outside the browser.
- Billing, payment processing, location management, reporting, charts, and
  CSV export remain outside this implementation.

The existing-account-only tenant-owner restriction above was superseded by
the server-side onboarding decision below. Auth-user creation remains outside
the browser.

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

The static host returned HTTP 200 after the tenant-administration commit was
pushed. That confirms static delivery only, not authenticated app, Supabase,
private photo, or mobile behavior. The tenant-management follow-up remains
local until separately validated and deployed.

The configured Supabase project displayed the missing-tenant-setup error.
This environment has no privileged database access; the migrations and
initial Super Admin provisioning must be applied through the approved
Supabase process before end-to-end Super Admin behavior can be verified.

## Server-side tenant-owner onboarding

- An existing email is assigned to the tenant without changing its Auth
  password.
- If the email is not registered, the `create-tenant-owner` Edge Function
  verifies the caller's JWT and database-backed Super Admin role before
  creating an email-confirmed Auth user. The service-role/secret key remains
  server-side.
- The function generates a cryptographically random temporary password. It
  is returned only to the authorized Super Admin and shown once in the
  tenant-creation dialog for secure forwarding; plaintext credentials are not
  stored in the database or logged.
- The new account is marked as requiring a password change. The Auth gate
  blocks the app, and PostgreSQL membership/Super Admin checks deny tenant
  data access until the authenticated owner changes the password through
  `complete-temporary-password-reset`.
- A request-ID ledger makes tenant creation retries idempotent. A partial
  account-creation failure is surfaced with the temporary password when it
  can be safely recovered, and retries reuse the same tenant request.
- The choice adds no paid service or Flutter runtime dependency. The new
  migration and Edge Functions remain unapplied/undeployed until reviewed and
  deployed through the approved Supabase process.

## Tenant member capacity and entry permissions

- Reuse `public.tenants` and `public.tenant_memberships`; do not introduce a
  second tenant, member, or device registry. Member identities must already
  exist in Supabase Auth; this feature does not create member accounts or
  invitations.
- Set each tenant's stored member limit to one by default, with a maximum of
  50. Owners are excluded from the count. Count current member-role rows;
  preserve existing rows even if an existing tenant is over its configured
  limit, and block new additions until capacity is available.
- Serialize member additions and owner-to-member role transitions by locking
  the tenant row. Return the stable `MEMBER_LIMIT_REACHED` error with limit,
  current usage, and remaining capacity details.
- Backfill existing memberships to retain full View/Add/Edit/Delete access;
  new members start View-only. Keep the four permissions independent and
  enforce them in PostgreSQL RLS and private Storage authorization.
- Tenant owners manage member-role accounts and permissions only in their
  own tenant. Super Admins retain cross-tenant management and are the only
  role allowed to change a tenant's member limit. Removal revokes membership
  access without deleting the Auth identity or parking history.
- Extend the local API with the same limit and permission behavior. Keep its
  `parking_api` role least-privileged; schema changes require the local
  database owner, and the migration helper refreshes table/sequence grants.
- Reuse the existing device-session policy and administration flow; do not
  create a parallel device registry or change policy precedence.
- Local Flutter and API security tests passed. SQL/RLS, PostgreSQL race, and
  migrated local API integration tests remain unverified because the local
  Supabase database is unavailable and the existing local API database lacks
  migration 003. No hosted migration, production write, commit, push, or
  deployment was performed.
