# Performance Baseline and Verification

- **Measured:** 2026-10-18
- **Repository baseline:** `main` at `a3faec0`
- **Model at measurement:** Authenticated, owner-scoped parking sessions

## Scope and limits

At measurement time the repository did not have tenant or membership tables.
The current uncommitted implementation adds tenant and Super Admin support in
response to the user's clarification. The measurements below predate that
implementation and are not post-change performance evidence.

The local release measurements below describe a Flutter Web artifact built
without production Supabase `--dart-define` values. They are not a
production-configured build or a benchmark of rendering, database latency,
camera use, or photo upload.

## Release artifact

The previous local inventory recorded 39 files totaling 42,447,286 bytes.
The release built for this pass contains 39 files totaling 42,450,799 bytes
(about 40.48 MiB), a difference of 3,513 bytes (about 0.01%). The
`main.dart.js` bundle is 3,159,525 bytes, compared with the earlier recorded
3,156,012 bytes. WebAssembly totals 28,834,146 bytes (about 27.50 MiB), and
symbol files total 8,581,625 bytes (about 8.18 MiB).

No release file name matched OCR/Tesseract/model asset names, and the output
contained no OCR runtime string matching the retired bridge, runtime, model,
or backend-URL identifiers.

The inventory was calculated by recursively summing the lengths of regular
files under `build/web`; MiB uses 1,048,576 bytes. It is an uncompressed file
inventory, not a network-transfer measurement.

## Query behavior

These request counts are derived from the implementation and request-level
tests; they are not measured production latency.

| Operation | Previous behavior | Current behavior |
| --- | --- | --- |
| Dashboard initial load | One unbounded session-list request plus one request returning every owned expiry timestamp | One page request for 10 sessions plus a sentinel row, and two parallel exact `HEAD` count requests |
| Dashboard search | Repeated the list and expiry-summary requests | One bounded list request; counts are not re-requested |
| History load | One unbounded matching-session request | 50-session pages plus a sentinel row; additional pages load on demand |
| Session ordering | `entry_time` descending | Stable `entry_time DESC, id DESC` ordering |

The Dashboard initial load now makes three PostgREST requests instead of two,
trading a second count-only request for transfer of all expiry timestamps.
Search-only changes make one list request rather than re-running the summary.
No database-latency reduction is claimed without hosted query-plan and
representative-data measurements.

At the time of this baseline, both count requests and each list request
explicitly filtered by the authenticated `created_by` user ID, in addition to
the owner-only RLS policies. The current working branch instead filters by
the selected tenant when one is selected; PostgreSQL tenant membership and
Super Admin policies remain the authorization boundary. The active boundary
is `expires_at > asOf`; the expired boundary is `expires_at <= asOf`. One UTC
`asOf` value is shared by the two counts.

The tenant migration, initial Super Admin provisioning, and production
behavior have not been applied or measured against the hosted project.

## Static-host sample

On 2026-10-18, unauthenticated GET requests to the production Pages origin
returned HTTP 200 for the root, `manifest.json`, `flutter_bootstrap.js`,
`flutter.js`, `main.dart.js`, and the 192- and 512-pixel app icons. The root
response included `X-Content-Type-Options: nosniff`,
`Referrer-Policy: strict-origin-when-cross-origin`, and
`Cache-Control: public, max-age=0, must-revalidate`.

These checks establish that the sampled static files are reachable. They do
not verify authentication, Supabase RLS, private Storage, Dashboard query
latency, installed-PWA behavior, or real-device performance.

## Existing photo-input limits

The existing photo picker requests a maximum image width and height of 1,600
pixels and the codec accepts JPEG, PNG, and WebP up to 10 MiB. These are
code-configured limits, not a benchmark of camera output, compression time,
upload duration, or mobile memory use. The photo pipeline and storage behavior
were not changed.

## Validation evidence

- `dart format .` — passed; 48 Dart files checked, none changed.
- `flutter analyze` — passed with no issues.
- `flutter test` — passed; 96 tests.
- `flutter build web --release` — passed. Flutter emitted a non-fatal
  Cupertino icon-font availability warning; the release was produced.
- Release inventory and OCR-asset/string checks — passed.
- Credential-pattern scan — no valid credential found. A case-insensitive
  scanner initially matched a lowercase generated bundle substring against
  the uppercase AWS key pattern; the match is not a valid AWS key.
- `git diff --check` — final result recorded in `PROGRESS.md`.

## Measurements still needed

The following need a configured non-production or production-like environment
and are not represented by these local/static measurements:

- Authenticated Dashboard and History request duration at representative
  session counts.
- Hosted Postgres query plans and RLS behavior for the list and count
  predicates.
- Multi-user ownership and private Storage isolation.
- Real desktop/mobile first render, camera, image selection, and photo upload
  behavior.
- PWA installation, resume, and refresh behavior on Android Chrome and iPhone
  Safari.
