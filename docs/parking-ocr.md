# Local vehicle-registration OCR

Phase 6 adds optional, browser-side OCR for a captured or selected vehicle
photo. OCR is an assistive step only: it produces a candidate, the user can
edit or reject it, and the parking session cannot be saved until the candidate
has been explicitly confirmed or the user chooses to keep a manual entry.

## Architecture and privacy

- `ParkingOcrService` keeps OCR independent of Flutter widgets, Supabase, and
  session persistence.
- Flutter passes the in-memory photo bytes to `web/parking_ocr.js`.
- The small bridge is loaded with the application shell, while the
  Tesseract.js runtime is loaded only when OCR is first requested.
- The adapter then creates a local Tesseract.js worker and returns recognized
  text.
- The worker, WebAssembly core, and English language model are served from the
  same static host as the Flutter app. Vehicle photos are not sent to an OCR
  provider, CDN, analytics service, or custom backend.
- The worker is terminated after success, failure, timeout, cancellation, or
  widget disposal. Each attempt has a 30-second timeout.
- If the local runtime is unavailable, OCR fails, finds no useful text, or is
  cancelled, manual entry, another photo, and **Continue without photo** remain
  available.

The browser still needs access to the selected image in memory. Supabase
authentication, the private Storage bucket, the row-first upload sequence, and
the `<user-id>/<session-id>/<filename>` path are unchanged.

## Bundled assets and licensing

The repository vendors the required Tesseract.js 7 LSTM runtime assets under
the versioned `web/ocr-v1/` directory:

- Tesseract.js runtime and worker.
- Standard, SIMD, and relaxed-SIMD LSTM WebAssembly core variants.
- The compressed English `eng.traineddata.gz` model.
- Apache License 2.0 notices in `web/ocr-v1/` and `web/ocr-v1/core/`.

The checked-in files total **31,397,609 bytes** (31.40 MB decimal, 29.94
MiB). That inventory includes all three WebAssembly core variants because the
worker selects the compatible LSTM variant at runtime. The variants remain in
the release until Android Chrome and iPhone Safari compatibility and
recognition accuracy have been measured; removing one based only on the
desktop result would be unsafe.

No new Flutter runtime dependency was added. The Dart Web adapter uses the
installed SDK's `dart:js_interop` APIs.

### Loading and cache audit

`web/index.html` no longer loads `tesseract.min.js` during application startup.
`web/parking_ocr.js` appends the runtime script on the first OCR request and
uses the versioned `ocr-v1/` paths for the runtime, worker, core, and model.
Changing OCR assets requires moving the bundle to a new versioned directory
and updating the bridge path. This prevents an updated OCR bundle from being
silently mixed with an older browser-cached bundle.

An isolated Chrome 154 measurement against the release build on a local
static server, with the first OCR request made with cache disabled, observed
these OCR requests:

| Asset | Bytes |
| --- | ---: |
| `tesseract.min.js` | 62,961 |
| `worker.min.js` | 111,307 |
| `tesseract-core-relaxedsimd-lstm.wasm.js` | 3,905,767 |
| `eng.traineddata.gz` | 10,923,060 |
| **Observed first-use total** | **15,003,095** |

The repeat request in the same browser session generated no additional OCR
asset requests. These are local uncompressed response sizes, not a promise of
production network transfer; a real static host may apply compression and
different cache headers. Configure the host to serve immutable versioned OCR
paths such as `/ocr-v1/*` with a long-lived policy such as
`Cache-Control: public, max-age=31536000, immutable`. Do not apply that policy
to Supabase responses, signed URLs, or private vehicle photos. If the hosting
provider cannot configure headers, the versioned paths still provide safe
cache invalidation, but repeat-download behavior remains browser/host
dependent.

## Hosting and base paths

`web/index.html` loads `parking_ocr.js`; the bridge loads the runtime on first
OCR use. The adapter resolves worker, core, and model paths from
`document.baseURI`. This preserves Flutter's `$FLUTTER_BASE_HREF` behavior
when the app is deployed under a static-host subpath.

The static host must serve JavaScript, WebAssembly, and `.gz` model files from
the same origin. A deployment that strips or rewrites files under
`web/ocr-v1/` will make OCR unavailable while leaving manual plate entry
usable.

## Recognition limitations

OCR is not authoritative plate recognition. Blur, glare, skew, low contrast,
occlusion, multiple text regions, and unusual fonts can produce an empty or
incorrect candidate. Similar characters such as `O`/`0`, `I`/`1`, and `B`/`8`
can be confused. The parser only trims, uppercases, normalizes OCR whitespace,
and ranks text lines; it does not impose a country-specific registration
format or silently replace ambiguous characters.

## Manual Chrome verification

Run the app on `localhost` with the public Supabase values and sign in:

1. Open **New Parking Entry** and choose a clear, front-facing plate photo.
2. Verify that the normal application load does not request
   `ocr-v1/tesseract.min.js`.
3. Start OCR and verify that the runtime, worker, selected core, and model
   load only at that point.
4. Verify that local OCR shows progress and displays a candidate for review.
5. Confirm the detected value, edit it manually, or choose **Keep current
   entry**. Verify that saving is blocked until the candidate is confirmed or
   rejected.
6. Repeat with a blurred, angled, low-contrast, and multiple-text image.
7. Test an image with no registration text and verify the no-text message and
   **Retry OCR** action.
8. Start OCR and click **Cancel OCR**. Verify that the form returns to manual
   entry and that a late OCR result does not change the field.
9. Test **Take photo**, **Choose file**, Retake/Replace, and **Continue without
   photo**. Camera testing still requires browser permission and a supported
   localhost or HTTPS context.

Automated tests cover candidate normalization, no-text output, fallback
availability, explicit confirmation, manual rejection, OCR failure/timeout
messaging, cancellation, and protection against late results. They do not
prove OCR accuracy or physical camera behavior on Android Chrome or iPhone
Safari.
