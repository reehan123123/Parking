# Parking session management

Phase 7 adds authenticated dashboard and history views over the existing
`parking_sessions` repository. The UI does not treat client-side filtering as
authorization: list, detail, update, and delete operations are performed
through the authenticated Supabase client and remain protected by RLS.

## Dashboard

The dashboard loads the authenticated user's sessions newest first and shows:

- active and expired counts calculated from the current time;
- recent sessions with normalized registration, local entry time, local
  expiry, and current status;
- server-side registration search using Supabase `ilike`;
- loading, empty, retryable error, and refresh states;
- a **New Parking Entry** action.

The active boundary is strict: a session is active only while the current time
is before `expires_at`. A session at or after `expires_at` is expired.
Dashboard counts are intentionally loaded from the unfiltered session set, so a
search does not change the meaning of the summary.

## History and details

History uses the same server-side search and newest-first ordering without
duplicating the repository query. Selecting a session opens a dedicated
responsive details page containing:

- registration number;
- local entry date/time;
- allowed duration and unit;
- expiry date/time and current status;
- a private vehicle photo when one is attached.

Photo display uses a short-lived signed URL created only after the repository
confirms that the requested session and `photo_path` belong to the current
authenticated user. Signed URLs are not stored in the database or domain
model. They are refreshed when the details page loads or the application
resumes.

## Editing

The details page opens the existing parking-entry form in edit mode. The form
preserves the original session ID and calls the same Phase 4
`ParkingDurationCalculator` used during creation. Changing entry time,
duration, or unit recalculates the expiry preview before the update is sent.

An existing photo is retained when no replacement is selected. A replacement
uses the existing private path when possible, or uploads a new
`<user-id>/<session-id>/<filename>` object before setting the row path for a
session without a photo. Failed row updates never report success; newly
created objects are removed or exposed through an explicit cleanup retry.

## Deletion and refresh

Deletion requires a confirmation dialog and ignores duplicate requests while
one delete is active. Because the current Storage policy requires the owned
session row to exist while its object is removed, the repository removes the
photo first and deletes the row second. Missing storage objects are treated as
already cleaned up. Any storage or row failure is shown as an error and the
session is not reported as deleted; the details page exposes a retry action.

Dashboard and history refresh after create, edit, and delete operations, on
explicit refresh, and when the application resumes. The details page also
refreshes on resume so the displayed active/expired status remains current.

## Limitations and manual checks

The local test suite covers repository mapping, server-side search forwarding,
summary boundaries, signed-photo authorization checks, update/delete ordering,
dashboard/history states, detail navigation, edit mode, and failure handling.
Hosted RLS/Storage behavior still requires verification against the intended
Supabase project. The UI currently loads the complete authenticated result set
returned by the repository; pagination is not implemented.
