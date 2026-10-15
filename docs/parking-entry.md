# Parking entry and vehicle photos

Phase 5 adds an authenticated **New Parking Entry** form. Phase 7 reuses the
same form for editing from the session details page. Dashboard/history lists,
search, deletion, and displaying stored photos are documented in
[parking-session-management.md](parking-session-management.md).

## Form behavior

- Plate numbers are trimmed and normalized to uppercase before saving.
- Blank values and values longer than 64 characters are rejected to match the
  `parking_sessions` constraint.
- Entry date and time are selected in the device's local time context.
- Allowed duration accepts positive whole numbers in minutes, hours, days, or
  calendar months.
- The form uses the Phase 4 `ParkingDurationCalculator` for the expiry
  preview and the saved value.
- The client-side maximum is configurable in
  `lib/features/parking/presentation/parking_entry_limits.dart`:
  - 525,600 minutes.
  - 8,760 hours.
  - 365 days.
  - 12 months.
- Entry and expiry timestamps are converted to UTC ISO-8601 strings only when
  sent to PostgreSQL.

## Photo behavior

The current schema has one nullable `photo_path`, so the form supports one
vehicle photo per session. A photo is optional only when the user explicitly
checks **Continue without photo**.

The **Take photo** action uses the official Flutter `camera: 0.12.1` package
and its endorsed `camera_web` implementation. It opens a live browser camera
preview only after the user clicks the action. When the browser reports lens
direction metadata, phones and tablets prefer the rear/environment camera;
desktop browsers prefer an external webcam. **Switch camera** cycles through
the available cameras when more than one can be opened. The dialog supports
**Capture**, **Retake**, **Use Photo**, and **Cancel**. The camera session is
disposed after a capture, camera-switch failure, and when the dialog closes or
the entry screen is disposed; **Retake** reopens the camera.

The **Choose file** action continues to use `image_picker` and opens the normal
file picker. Browser support varies:

- Camera access works on `localhost` during development and requires HTTPS for
  deployed sites.
- Chrome prompts for camera permission when the preview opens. Permission
  denial, missing cameras, unsupported browser behavior, and initialization or
  capture or camera-switch failures remain inside the dialog as clear errors.
  Initialization, capture, and camera switching are bounded by a 20-second
  timeout; a timeout releases the camera session and exposes a **Retry** action
  instead of leaving the dialog loading indefinitely. **Cancel** remains
  available while a capture is in progress.
- Desktop browsers may have no usable webcam; **Choose file** remains the
  fallback.

Selected images are kept in memory for preview. File-picker images are
requested with an approximate 1600-pixel bound and quality 85 where supported.
Captured and selected images must be no larger than 10 MB. JPEG, PNG, and WebP
images are accepted.

## Save and cleanup sequence

The client uses only the authenticated Supabase session and the public
publishable key:

1. Recheck that a current authenticated user exists.
2. Insert `parking_sessions` with the exact migration column names and the
   normalized plate, UTC entry time, duration value/unit, UTC expiry, and
   `created_by`.
3. Build the private object path:

   ```text
   <user-id>/<parking-session-id>/<safe-filename>
   ```

4. Record that path on the owned row so a failed operation has a recovery
   reference.
5. Upload the in-memory bytes to the private `vehicle-photos` bucket.
6. Report success only after the upload completes.

If the path update or upload fails, the app removes the object while the row
still exists and then attempts to delete the incomplete row. If object cleanup
or row deletion fails, the owned row is retained and the form exposes
**Retry cleanup**. The form never reports a complete save when a required
upload has failed.

## Editing an existing session

The edit form initializes its plate, local entry date/time, duration, expiry
preview, and existing private photo path from the selected session. It always
reuses the Phase 4 duration calculator; it does not recalculate expiry with
widget-local date arithmetic.

- Saving without selecting a replacement retains the existing `photo_path`.
- Selecting a camera or file photo replaces the existing object at its
  session-scoped path.
- Adding a photo to a session that has none uploads the object before updating
  the row. If the row update fails, the new object is removed or exposed for
  explicit cleanup retry.
- Existing photos are not removed independently in this phase.

The session ID is retained when the form submits an edit, so updates remain
scoped to the authenticated owner through the repository and Supabase RLS.

The Storage policies remain the security boundary. No public bucket, signed
URL, service-role key, database password, or custom API is used by this flow.

## Optional local OCR

After a photo is captured or selected, the Phase 6 browser-side OCR service
can read a registration candidate using the locally hosted Tesseract.js
runtime. The candidate is normalized with the same trim-and-uppercase rules
as manual input, shown for review, and never treated as authoritative. The
user must confirm it or explicitly keep a manual value before saving.

OCR can be cancelled, times out after 30 seconds, fail, return no useful text,
or be unavailable in a non-Web test build. Each path keeps manual entry,
retaking/replacing the photo, retrying OCR, and **Continue without photo**
available. Vehicle photos remain in memory during OCR and are not sent to a
third-party OCR service. See [parking-ocr.md](parking-ocr.md) for the local
asset, licensing, hosting, privacy, and browser-testing details.

## Manual verification

With the migration and private user already created in the intended Supabase
project:

1. Run the web app with the public URL and publishable key through
   `--dart-define`.
2. Sign in with the administrator-created account.
3. Open **New Parking Entry** from the Dashboard.
4. Verify plate normalization, each duration unit, the expiry preview, and the
   explicit no-photo option.
5. Click **Take photo** and verify that Chrome requests permission and shows a
   live webcam preview. On a phone or tablet, verify that the rear camera is
   preferred when available and that **Switch camera** cycles cameras. Test
   **Capture**, **Retake**, **Use Photo**, and **Cancel**.
6. Test **Choose file** and verify the normal file picker still accepts
   JPEG/PNG/WebP images.
7. Confirm the new row has the expected UTC timestamps and that the photo
   object is private at the expected user/session path.
8. Test denied photo permissions, unavailable cameras, an oversized/unsupported
   image, and a network interruption. The UI must show an error and must not
   claim success.
9. Test OCR with a clear plate, a blurred/angled plate, multiple text regions,
   no text, cancellation, retry, manual correction, and explicit confirmation.

Local Flutter tests cover validation, calculator composition, persistence
mapping, row-before-upload order, cleanup failure handling, camera dialog
states, camera disposal, entry-page camera integration, OCR candidate review,
manual fallback, and cancellation. They do not prove hosted RLS/Storage
behavior, OCR accuracy, or physical camera support on Android/iPhone.
