# Parking Management SaaS — Robustness, Performance and Cost-Efficiency Plan

## 1. Goal

Make the existing multi-tenant Parking Management PWA secure, maintainable, fast and economical. Optimize database storage, query load, initial page load, network bandwidth, photo storage, reports and operational reliability.

Intended stack:
- Flutter Web / Dart
- Supabase Auth, PostgreSQL and private Storage
- Cloudflare Pages
- GitHub Actions
- `fl_chart` for charts, after compatibility verification
- Flutter-native paginated tables
- PostgreSQL-side filtering and aggregation
- CSV export

Copilot must inspect the actual repository and verify its current state before assuming files, dependencies, schema or deployment configuration.

## 2. Non-negotiable rules

1. Enforce tenant isolation in PostgreSQL RLS and trusted operations, not only in UI filters.
2. Measure performance before and after changes; do not invent speed or cost improvements.
3. Do not add Redis, a separate analytics database, a message broker or paid monitoring unless measurements justify it and I approve any cost.
4. Never weaken authorization, payment accuracy, auditability or data integrity to save resources.
5. Do not delete historical financial records to reduce storage.
6. Do not fetch every parking record to render a dashboard, table or report.
7. Do not apply production migrations, delete production data, commit, push or deploy without explicit approval.
8. Ask essential business questions once, with recommended defaults. For reversible implementation choices, choose the best option, document it and continue.
9. Record significant decisions in checkpoints and continue rather than stopping after every phase.
10. Clearly label checks as passed, failed, blocked or untested.

## 3. Charts and reports

Use `fl_chart` for line, bar and pie/doughnut-style charts if compatible with the current Flutter SDK and project. Verify the current dependency and SDK compatibility before adding/upgrading it.

Use Flutter-native tables for report details. Provide accessible text/table alternatives for key chart values.

Charts:
- Line: daily/monthly parking activity and recorded collections.
- Bar: collections or sessions by location and billing type.
- Pie/doughnut: payment status distribution, with exact figures available in a table.
- KPI cards: active vehicles, expiring passes, overdue balances and recorded collections.

Do not load every report/chart on initial page load. Load detailed reports on demand.

Reports should support bounded date ranges, tenant/location filters where authorized, billing type, payment status, pagination, sorting and CSV export.

Perform filtering, sorting and aggregation in PostgreSQL. Return only necessary columns and aggregated values. Exports must use the same authorization as the UI, stream or batch large results, and escape CSV formula-leading values safely.

## 4. Database storage efficiency

Inspect the current schema before adding or changing tables.

- Use existing ID types consistently; do not migrate IDs merely for theoretical savings.
- Use `timestamptz` for instants and define tenant/location time zones for business-day boundaries.
- Use appropriate constraints and lengths for registration numbers and mobile numbers.
- Use exact monetary representation (`numeric` with an appropriate scale, or carefully defined integer minor units); never use floating-point money arithmetic.
- Avoid storing repeated names, formatted labels, chart data, redundant JSON copies or derivable totals.
- Preserve an immutable pricing/rate snapshot for historical charges where needed.
- Avoid duplicating payment totals in multiple tables unless a measured need and reconciliation strategy justify it.
- Keep relational columns for fields used in filtering, joining and constraints. Use JSON only for genuinely variable settings/metadata.
- Do not store photos or base64 images in PostgreSQL rows; use private object storage.
- Avoid redundant photo copies and thumbnails unless measured benefits justify them.
- Define retention rules for photos and audit logs only after reviewing operational and legal needs.
- Never delete or rewrite historical charges/payments to save space; use traceable corrections/refunds.

## 5. Indexes and query design

Indexes consume storage and slow writes, so do not index every column.

- Inspect current indexes and actual query patterns.
- Index tenant-scoped foreign keys and common filters only where justified.
- Evaluate composite indexes such as tenant + status + timestamp against real predicates and sorting.
- Avoid duplicate/overlapping indexes.
- Consider partial indexes only when query patterns support them.
- Use `EXPLAIN (ANALYZE, BUFFERS)` on a safe test database with representative data.
- Do not run heavy profiling or load tests against production without approval.
- Use bounded date ranges, server-side pagination and stable ordering.
- Consider keyset/cursor pagination for large or frequently changing lists.
- Debounce search; constrain allowed sort columns and maximum page size.
- Avoid unbounded substring searches without a demonstrated strategy.

## 6. Tenant security

- Enforce RLS on every tenant-owned table.
- Resolve tenant membership and roles from trusted database-backed relationships.
- Never trust a browser-provided tenant ID or role by itself.
- Protect Super Admin operations and prevent users assigning themselves privileged roles.
- Never put the Supabase service-role key in browser code.
- Restrict private photo access and signed URL creation to authorized tenant/session owners.
- Apply the same authorization to dashboard aggregates, tables, exports and storage.
- Test cross-tenant reads, inserts, updates, deletes, direct-ID lookups, report functions and photo access.
- Preserve equivalent authorization when optimizing RLS or query plans.
- Never disable RLS to fix a performance problem.

## 7. Flutter Web and initial load

- Capture release build size and asset sizes before optimization.
- Remove unused dependencies/assets only after checking all references.
- Avoid large packages when existing Flutter widgets are sufficient.
- Lazy-load report screens and optional features.
- Avoid expensive calculations, huge tables and image decoding on the UI thread.
- Use list builders and pagination for long lists.
- Scope widget rebuilds; dispose controllers, subscriptions and image resources.
- Avoid repeated requests when tenant, filters and relevant data have not changed.
- Debounce searches and ignore/cancel stale requests.
- Provide loading, empty, error and offline/failure states.
- Keep service-worker updates reliable.
- Never publicly cache authenticated API responses, user-specific records or private photos.

## 8. Cloudflare Pages and caching

- Build optimized Flutter release assets.
- Verify MIME types, compression and cache headers using actual response headers.
- Use long-lived immutable caching only for fingerprinted/versioned assets.
- Revalidate entry HTML, manifest and service-worker files appropriately so releases are picked up.
- Verify deep-link refresh behavior and PWA update behavior.
- Never apply shared public cache rules to private Supabase data or photos.
- Do not assume compression or caching is correct without testing.

## 9. Photo bandwidth and storage

Vehicle photos may consume more storage and bandwidth than database rows.

- Preserve camera capture, file selection, preview, retake/replace and private storage.
- Validate image type and size before upload.
- Resize/compress client-side when supported, retaining enough detail to identify the vehicle/plate.
- Choose documented maximum dimensions/size after testing on real mobile devices.
- Prefer efficient JPEG/WebP output when compatible, with safe fallbacks.
- Avoid re-uploading unchanged images.
- Show upload progress and retry failures safely.
- Use thumbnails for list views only when useful; do not download full-resolution originals for every row.
- Use short-lived signed URLs or another appropriately private delivery mechanism.
- Do not make the bucket public to simplify loading.
- Measure compression savings and ensure image legibility before adopting aggressive settings.

## 10. Dashboard efficiency

- Define every metric precisely, including time-zone boundaries, partial payments and refunds.
- Fetch only the small set of metrics needed for the initial dashboard.
- Combine compatible counts/sums into a small number of authorized aggregate queries.
- Do not fetch all sessions to calculate active, expiring, expired or overdue counts.
- Fetch detail tables only when opened.
- Cache only safe, correctly scoped in-memory data when measurements show benefit; invalidate after relevant writes.
- Clear tenant-specific cached data on tenant switch and sign-out.
- Consider pre-aggregated tables/materialized views only after measuring a real bottleneck. Document freshness, update, reconciliation and rebuild procedures.
- Distinguish expiry from payment status; an expired pass is not necessarily unpaid.

## 11. Billing and data integrity

- Store the applied pricing rule/rate snapshot so future price changes do not rewrite historical charges.
- Use transactions for related session, charge and payment updates.
- Prevent duplicate payment submissions with appropriate idempotency/constraints.
- Separate generated charges, money actually collected and outstanding balances.
- Make corrections and refunds traceable.
- Do not rely only on client-calculated amounts.
- Keep monetary rounding deterministic and tested.
- If denormalized totals are introduced, define how they are updated and reconciled.

## 12. Robustness and recovery

- Handle network errors, timeouts, rate limits and Supabase errors explicitly.
- Avoid duplicate submissions and inconsistent partial writes.
- Use structured, non-sensitive diagnostics; never log tokens, credentials or unnecessary personal data.
- Document backup, restore and migration procedures appropriate to the actual hosting plan.
- Do not claim monitoring, backups or recovery are configured unless verified.
- Use background jobs only when a real requirement justifies them; simple expiry counts should normally be query-based.
- Make notification jobs idempotent if reminders are introduced.

## 13. Baseline and acceptance criteria

Before optimizing, measure what is available:
- Flutter release build size and largest assets.
- First meaningful render and time until dashboard is usable.
- Initial request count and payload size.
- Dashboard query count and latency.
- Parking list latency at representative page sizes.
- Report query latency/result size.
- Photo size before/after compression and upload duration.
- Query plans/index usage in a safe test database.

Repeat the same measurements after changes under comparable conditions. Set performance targets from the baseline instead of inventing guarantees.

Acceptance checks:
- Dashboard does not download every parking record.
- Initial load does not fetch unnecessary report/chart data.
- Large tables use server-side pagination.
- Reports aggregate in PostgreSQL and respect tenant isolation.
- Photos are appropriately sized and still identifiable.
- Private data is not publicly cached.
- RLS still blocks cross-tenant access.
- Financial totals remain correct.
- All results are labeled measured, estimated, blocked or untested as appropriate.

## 14. Copilot execution instructions

1. Inspect the repository, current dependencies, schema, RLS, UI and deployment setup.
2. Record a baseline and identify likely bottlenecks.
3. Prepare a prioritized plan based on security impact, measured performance, cost and complexity.
4. Ask essential business questions once and recommend defaults.
5. Implement low-risk, high-impact changes first.
6. Add security/data-correctness tests before optimizing sensitive queries.
7. Make schema changes as reviewable migrations and preserve existing data.
8. Measure before and after.
9. Run available checks:
   - `dart format .`
   - `flutter analyze`
   - `flutter test`
   - `flutter build web --release`
   - `git diff --check`
10. Document decisions, limitations and results.

Maintain or adapt these files:
- `docs/implementation/PERFORMANCE_PLAN.md`
- `docs/implementation/PERFORMANCE_BASELINE.md`
- `docs/implementation/DECISIONS.md`
- `docs/implementation/CHECKPOINTS.md`
- `docs/implementation/PROGRESS.md`

Continue autonomously through ordinary implementation choices and record significant decisions in checkpoints. Stop for destructive production changes, production migrations, paid services, commits, pushes and deployment approval.

## 15. Final report

Report:
- Files and features changed.
- Database storage/index trade-offs.
- Build size before/after.
- Initial-load/dashboard performance before/after where measurable.
- Query count, query plans and report latency where measurable.
- Photo compression and bandwidth results.
- RLS/security regression results.
- Tests and build results.
- Optimizations deferred because evidence did not justify them.
- Remaining blockers and exact next steps.

Do not claim speed, storage or cost improvements without measurements or clearly labeled estimates.

Start with repository inspection and baseline measurement. Prepare the prioritized plan before editing. Do not change production configuration or deploy without explicit approval.
