# Parking entry and vehicle photos

The **New Parking Entry** form is available to authenticated tenant members
and Super Admins. The same form is used for editing from the session details
page. Dashboard, History, tenant selection, and session management are
documented in [parking-session-management.md](parking-session-management.md).

## Form behavior

- Plate numbers are trimmed and normalized to uppercase before saving.
- Blank values and values longer than 64 characters are rejected to match the
  `parking_sessions` constraint.
- Entry date and time are selected in the device's local time context.
- Allowed duration accepts positive whole numbers in minutes, hours, days, or
  calendar months.
- The form uses the shared `ParkingDurationCalculator` for the expiry preview
  and saved value.
- The client-side maximum is configurable in
  `lib/features/parking/presentation/parking_entry_limits.dart`:
  - 525,600 minutes.
  - 8,760 hours.
  - 365 days.
  - 12 months.
- Entry and expiry timestamps are converted to UTC ISO-8601 strings only when
  sent to PostgreSQL.
- A tenant must be selected before a new session can be created. Super Admins
  may select a specific tenant; tenant members use their assigned workspace.

## Photo behavior

The schema has one nullable `photo_path`, so the form supports one vehicle
photo per session. A photo is optional only when the user explicitly checks
**Continue without photo**.

The **Take photo** action uses the official Flutter `camera: 0.12.1` package
and its endorsed `camera_web` implementation. It opens a live browser camera
preview only after the user clicks the action. When the browser reports lens
direction metadata, phones and tablets prefer the rear/environment camera;
desktop browsers prefer an external webcam. **Switch camera** cycles through
available cameras when more than one can be opened. The dialog supports
**Capture**, **Retake**, **Use Photo**, and **Cancel**. The camera session is
disposed after a capture, camera-switch failure, and when the dialog closes or
the entry screen is disposed; **Retake** reopens the camera.

The **Choose file** action continues to use `image_picker` and opens the normal
file picker. Browser support varies:

- Camera access works on `localhost` during development and requires HTTPS for
  deployed sites.
- Chrome prompts for camera permission when the preview opens. Permission
  denial, missing cameras, unsupported browser behavior, and initialization,
  capture, or camera-switch failures remain inside the dialog as clear errors.
  Initialization, capture, and camera switching are bounded by a 20-second
  timeout; a timeout releases the camera session and exposes a **Retry**
  action instead of leaving the dialog loading indefinitely. **Cancel**
  remains available while a capture is in progress.
- Desktop browsers may have no usable webcam; **Choose file** remains the
  fallback.

Selected images are kept in memory for preview. File-picker images are
requested with an approximate 1600-pixel bound and quality 85 where
supported. Captured and selected images must be no larger than 10 MB. JPEG,
PNG, and WebP images are accepted.

## Save and cleanup sequence

In production/default mode, the client uses the authenticated Supabase
session and public publishable key. PostgreSQL RLS authorizes parking access
using tenant membership or the database-backed Super Admin role. The
opt-in local mode uses the loopback API and local photo directory instead;
its authorization is local-only and does not verify Supabase RLS. See
[Local PostgreSQL development](local-development.md) for its setup.

The production/default save sequence is:

1. Recheck that a current authenticated user and selected tenant exist.
2. Insert `parking_sessions` with the exact migration column names, selected
   `tenant_id`, authenticated `created_by`, normalized plate, UTC entry time,
   duration value/unit, and UTC expiry.
3. Build the private object path:

   ```text
   <created-by-user-id>/<parking-session-id>/<safe-filename>
   ```

4. Record that path on the session so a failed operation has a recovery
   reference.
5. Upload the in-memory bytes to the private `vehicle-photos` bucket.
6. Report success only after the upload completes.

If the path update or upload fails, the app removes the object while the
session still exists and then attempts to delete the incomplete session. If
object cleanup or row deletion fails, the row is retained and the form
exposes **Retry cleanup**. The form never reports a complete save when a
required upload has failed.

## Editing an existing session

The edit form initializes its plate, local entry date/time, duration, expiry
preview, and existing private photo path from the selected session. It uses
the same duration calculator; it does not recalculate expiry with
widget-local date arithmetic.

- Saving without selecting a replacement retains the existing `photo_path`.
- Selecting a camera or file photo replaces the existing object at its
  session-scoped path.
- Adding a photo to a session that has none uploads the object before
  updating the row. If the row update fails, the new object is removed or
  exposed for explicit cleanup retry.
- Existing photos are not removed independently in this flow.

The session ID and tenant scope are retained when the form submits an edit.
Database RLS remains the authorization boundary for both tenant members and
Super Admins.

## Registration entry

Vehicle registration is entered and reviewed manually. The value is trimmed
and uppercased before saving; the application does not infer or rewrite
characters from the vehicle photo. Photo capture, file selection, preview,
replacement, and upload remain independent of registration entry.

## Manual verification

After the tenant migration and initial Super Admin role have been configured
in the intended Supabase project:

1. Run the web app with the public URL and publishable key through
   `--dart-define`.
2. Sign in with an existing tenant member or Super Admin account.
3. Select the intended tenant (Super Admin only), then open **New Parking
   Entry** from the Dashboard.
4. Verify plate normalization, each duration unit, expiry preview, and the
   explicit no-photo option.
5. Click **Take photo** and verify that the browser requests permission and
   shows a live camera preview. On a phone or tablet, verify that the rear
   camera is preferred when available and that **Switch camera** cycles
   cameras. Test **Capture**, **Retake**, **Use Photo**, and **Cancel**.
6. Test **Choose file** and verify the normal file picker accepts JPEG/PNG/WebP
   images.
7. Confirm the session has the selected `tenant_id`, authenticated
   `created_by`, expected UTC timestamps, and a private photo object at the
   expected creator/session path.
8. Test denied camera permissions, unavailable cameras, oversized or
   unsupported images, and a network interruption. The UI must show an error
   and must not claim success.
9. Verify that selecting or capturing a photo does not change the manually
   entered registration and saving works without any image-processing
   initialization.

Local Flutter tests cover validation, duration-calculator composition,
persistence mapping, tenant selection, row-before-upload order, cleanup
failure handling, camera dialog states, camera disposal, entry-page camera
integration, manual registration, and photo replacement/cleanup. They do not
prove hosted RLS/Storage behavior or physical camera support on Android/iPhone.
