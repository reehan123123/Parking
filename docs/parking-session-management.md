# Parking session management

The authenticated Dashboard and History views use the tenant-aware
`parking_sessions` repository. The UI does not treat client-side filtering as
authorization: list, detail, update, and delete operations use the
authenticated Supabase client and remain protected by tenant RLS.

Tenant members see their selected workspace. A database-provisioned Super
Admin can select one tenant or all tenants. The `owner` and `member`
membership roles currently have the same parking-session permissions.

## Dashboard

The Dashboard loads a bounded, newest-first preview for the selected tenant
and shows:

- active and expired counts calculated for the current tenant scope;
- recent sessions with normalized registration, local entry time, local
  expiry, and current status;
- server-side registration search using Supabase `ilike` within the selected
  tenant;
- loading, empty, retryable error, and refresh states;
- a **New Parking Entry** action.

The active boundary is strict: a session is active only while the current time
is before `expires_at`. A session at or after `expires_at` is expired.
Dashboard counts are independent of registration search, so typing a search
does not change the summary. The Dashboard requests 10 sessions plus one
sentinel row. A Super Admin may choose a tenant or the global all-tenant view.

## History and details

History requests 50 sessions per page, uses the same server-side search and
stable newest-first ordering, and loads further pages on demand. Selecting a
session opens a responsive details page containing:

- registration number;
- local entry date/time;
- allowed duration and unit;
- expiry date/time and current status;
- a private vehicle photo when one is attached.

Photo display uses a short-lived signed URL created only after the repository
confirms that the requested session and `photo_path` are accessible to the
current tenant member or Super Admin under RLS. Signed URLs are not stored in
the database or domain model. They are refreshed when the details page loads
or the application resumes.

## Editing

The details page opens the parking-entry form in edit mode. The form preserves
the original session ID and calls the same `ParkingDurationCalculator` used
during creation. Changing entry time, duration, or unit recalculates the
expiry preview before the update is sent.

An existing photo is retained when no replacement is selected. A replacement
uses the existing private path when possible, or uploads a new
`<created-by-user-id>/<session-id>/<filename>` object before setting the row
path for a session without a photo. Failed row updates never report success;
newly created objects are removed or exposed through an explicit cleanup
retry.

## Deletion and refresh

Deletion requires a confirmation dialog and ignores duplicate requests while
one delete is active. Because Storage authorization checks the related
tenant-authorized session while its object is removed, the repository removes
the photo first and deletes the row second. Missing storage objects are
treated as already cleaned up. Any storage or row failure is shown as an
error and the session is not reported as deleted; the details page exposes a
retry action.

Dashboard and History refresh after create, edit, and delete operations, on
explicit refresh, and when the application resumes. The details page also
refreshes on resume so the displayed active/expired status remains current.
Search and refresh reset History pagination; loading additional pages appends
results in stable order.

## Limitations and manual checks

The local test suite covers tenant filters, server-side search, summary
boundaries, signed-photo authorization checks, pagination, update/delete
ordering, dashboard/history states, detail navigation, edit mode, and failure
handling. Hosted RLS/Storage behavior still requires verification against the
intended Supabase project. Member management, user invitations, billing,
payments, locations, reports, and exports are not implemented.
