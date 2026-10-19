# Parking Management PWA — Product Requirements and Copilot Build Workflow

## 1. Project objective

Build a small, private parking management Progressive Web App (PWA) that runs from one responsive web codebase on:

- Desktop browsers
- Android Chrome (installable to the home screen)
- iPhone Safari (Add to Home Screen)

The app is for personal or small private parking use. The priority is minimal maintenance, minimal operational cost, a small dependency footprint, and code that can be developed and tested incrementally with GitHub Copilot.

**Do not build native Android/iOS applications.** Build and deploy the web app only. Do not require Google Play or Apple App Store publishing.

## 2. Required technology stack

- **Frontend:** Flutter Web with Dart.
- **Backend/database/authentication:** Supabase (PostgreSQL + Supabase Auth + Row Level Security).
- **Photo storage:** Supabase Storage using a private bucket.
- **Source control:** GitHub.
- **Web hosting:** Cloudflare Pages, or another static host whose terms permit this use.
- **Development assistant:** GitHub Copilot Agent mode.
- **Testing:** Dart/Flutter formatter, analyzer, unit tests, and practical browser/device tests.

Use stable versions compatible with the installed Flutter SDK. Verify current package APIs before adding dependencies. Prefer Flutter built-in widgets and standard libraries. Add a package only when it provides a clear benefit. Do not add state-management frameworks, custom backend services, paid APIs,
analytics, push notifications, OCR, image-processing services, or other
infrastructure unless explicitly approved.

## 3. Non-goals

Do not implement these in the first version:

- OCR, automatic registration recognition, and uploading vehicle images to
  third-party image-processing services.
- Payments, fines, invoicing, subscriptions, or billing.
- Parking-slot allocation or reservations.
- Multi-location administration.
- Custom .NET/API server, Docker, Kubernetes, Redis, background job server, or virtual machine.
- Native Android/iOS build and store release workflows.
- Mandatory custom domain.
- Full offline operation or offline photo-upload queue.

## 4. Core user workflow

1. User opens the HTTPS app URL or launches the installed home-screen PWA.
2. User signs in.
3. Dashboard shows active and expired parking sessions.
4. User selects **New Parking Entry**.
5. User captures a vehicle/number-plate photo with the browser camera, or selects an existing photo if camera access is unavailable.
6. User previews the photo and can retake or replace it.
7. User enters and reviews the vehicle registration manually.
8. User selects the entry date and time.
9. User chooses an allowed duration unit: **minutes, hours, days, or months**.
10. User enters a positive whole-number duration.
11. App calculates and displays the expiry date/time before saving.
12. User confirms and saves the parking session.
13. App uploads the photo to private Supabase Storage and saves the database record with a safe failure-handling strategy.
14. Dashboard refreshes and displays the new session with Active/Expired status.
15. User can search and open session details, including the photo and expiry.
16. User can edit or delete a session they are authorized to manage.
17. User can sign out.

## 5. Functional requirements

### 5.1 Authentication

- Require authentication for all parking data and private photos.
- Use Supabase Auth with a straightforward sign-in flow.
- Do not expose service-role keys or any privileged secret in the Flutter client.
- Document how the initial user account is created.
- Do not implement public self-registration unless specifically approved. Prefer invite/admin-created users or a documented private setup.

### 5.2 Dashboard

Display:
- Active session count.
- Expired session count.
- Search field for plate number.
- A list of sessions with plate number, entry time, expiry, and status.
- A clear **New Parking Entry** action.
- Loading, empty, and error states.

Status rule:
- Active if current time is earlier than `expires_at`.
- Expired if current time is greater than or equal to `expires_at`.

Do not use a background job merely to update the status. Compute status from the stored expiry timestamp when querying/displaying records. Refresh status when the app resumes or the dashboard refreshes.

### 5.3 New/edit parking session

Fields:
- Plate number (required, trimmed and normalized to uppercase; avoid overly restrictive assumptions about regional plate formats).
- Vehicle photo (optional only if the user explicitly chooses to continue without a photo; otherwise required for normal flow).
- Entry date (required).
- Entry time (required).
- Allowed duration value (positive whole number).
- Allowed duration unit: `minutes`, `hours`, `days`, or `months`.
- Expiry preview (read-only).
- Save and Cancel actions.

Validation:
- Reject blank plate numbers.
- Reject zero, negative, fractional, or non-numeric durations.
- Set a configurable sensible maximum duration; document the chosen default and keep it easy to change.
- Validate date/time and calculated expiry.
- Show understandable errors. Do not silently discard input.

### 5.4 Duration/expiry rules

Use a single, tested duration-calculation service, separate from UI and database code.

- Minutes: add the specified number of minutes.
- Hours: add the specified number of hours.
- Days: add calendar days while preserving local wall-clock time where possible.
- Months: add calendar months, **not** a fixed number of days.
- For month-end overflow, clamp to the last valid day of the target month. Example: January 31 + 1 month = the last day of February.
- Handle leap years.
- Store timestamps consistently in UTC in PostgreSQL (`TIMESTAMPTZ`) and display in the device's local time zone.
- Ensure the expiry preview and saved `expires_at` use the same calculation logic and agree.
- Test daylight-saving transitions where applicable. The primary anticipated locale is India, but do not hardcode the app to one time zone.
- Define how invalid/nonexistent local times are handled and document the behavior.
- The UI must clearly label the selected entry time and expiry time.

### 5.5 Photo capture and storage

- Implement browser camera capture using a Flutter-compatible approach that works on current Android Chrome and iPhone Safari.
- The app must be served over HTTPS for normal camera access.
- Include a file-upload fallback.
- Provide preview, retake, and cancel.
- Compress/resize photos client-side if this can be done reliably without adding excessive dependencies; otherwise enforce a documented image-size limit.
- Use a private Supabase Storage bucket.
- Save only the storage object path in the database, not a permanent public URL.
- Display images using authenticated access or short-lived signed URLs.
- Never make the bucket public to avoid implementing authentication.
- Handle camera denial, unavailable camera, unsupported browser, too-large file, upload failure, and network failure with helpful messages.
- Avoid orphaned files and incomplete records. Document and implement a safe upload/save sequence with cleanup on failure where practical.

### 5.6 History and details

- Search sessions by plate number.
- Display newest entries first.
- Show photo, plate number, entry date/time, allowed duration, expiry date/time, and status.
- Support editing and deletion only for authorized records.
- Confirm destructive deletion with a clear dialog.
- When deleting a record, also remove its stored photo where possible; handle cleanup failure without corrupting record state.

## 6. Data model

Create SQL migrations in source control. Do not rely on manually created undocumented database changes.

### Tables: `tenants`, `tenant_memberships`, and `super_admins`

- `tenants`: `id UUID PRIMARY KEY`, validated `name`, unique `slug`,
  nullable `created_by UUID REFERENCES auth.users(id)`, and `created_at`.
- `tenant_memberships`: `tenant_id UUID REFERENCES tenants(id)`,
  `user_id UUID REFERENCES auth.users(id)`, and a constrained role of
  `owner` or `member`, with `(tenant_id, user_id)` as the primary key.
- `super_admins`: `user_id UUID PRIMARY KEY REFERENCES auth.users(id)` and
  `created_at`. Authenticated clients must not have direct insert/update
  privileges.

When adding tenant support to an existing deployment, create one personal
workspace and owner membership for each existing Auth user, then backfill that
user's sessions without changing `created_by`, timestamps, expiry values, or
photo paths.

### Table: `parking_sessions`

Recommended fields:
- `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`
- `tenant_id UUID NOT NULL REFERENCES public.tenants(id)`
- `plate_number TEXT NOT NULL`
- `photo_path TEXT NULL`
- `entry_time TIMESTAMPTZ NOT NULL`
- `allowed_duration_value INTEGER NOT NULL`
- `allowed_duration_unit TEXT NOT NULL CHECK (allowed_duration_unit IN ('minutes','hours','days','months'))`
- `expires_at TIMESTAMPTZ NOT NULL`
- `created_by UUID NOT NULL REFERENCES auth.users(id)`
- `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`
- `updated_at TIMESTAMPTZ NOT NULL DEFAULT now()`

Add sensible constraints for positive duration values and indexes for `plate_number`, `expires_at`, and, if useful, `created_by`. Do not make `plate_number` unique: the same vehicle may park more than once.

Keep the schema small. Add tables only when a concrete requirement needs them.

## 7. Security requirements

- Enable RLS on every table accessible through the Supabase client.
- Create explicit policies so authenticated users can only read/insert/update/delete records in tenants where they have a membership. Inserts must bind `created_by` to `auth.uid()`, and regular members cannot transfer sessions between tenants or change their creator.
- Keep Super Admin authorization database-backed. Never allow a client to grant itself the role; only a controlled administrative operation may provision the initial Super Admin.
- Ensure Storage policies protect photos by checking the related session's creator path and tenant membership, with cross-tenant access reserved for a database-authorized Super Admin. Avoid overly broad authenticated-user policies.
- Allow only a Super Admin to create a tenant, and assign its owner to an existing Supabase Auth account. Do not create Auth users from the browser or expose a service-role key.
- The frontend may use only the Supabase project URL and publishable/anon key. Never use the service-role key in the client, GitHub, build artifacts, logs, or documentation.
- Put local configuration/secrets in ignored environment/config files as appropriate. Commit an example configuration file with placeholders, not real secrets.
- Validate user input in the client and use database constraints/RLS as the security boundary.
- Do not disable RLS to make a test pass.
- Do not log access tokens or secrets.
- Document how to rotate credentials and how to export/backup data.

## 8. PWA requirements

- Configure web app name, short name, icons, theme color, and standalone display where supported.
- Ensure the deployed app uses HTTPS.
- Make the layout responsive for mobile portrait, mobile landscape, tablet, and desktop.
- Provide clear guidance for installation:
  - iPhone: open in Safari → Share → Add to Home Screen.
  - Android: open in Chrome → Install app or Add to Home screen, depending on browser.
- Test camera access both in a browser tab and when launched from the home screen.
- Do not promise complete offline operation. The app needs internet for Supabase operations.
- If a service worker/offline cache is configured, cache only safe static assets. Never cache private API responses or photos in a way that leaks user data.
- Configure SPA fallback/routing correctly for the selected static host.
- Verify Flutter Web base-path configuration for the chosen hosting URL.

## 9. Deployment and operational plan

- Store all source code and SQL migrations in GitHub.
- Develop locally and run tests before pushing.
- Deploy the Flutter Web release build to Cloudflare Pages (or another suitable static host).
- Configure Supabase project URL and publishable key for the production build without including privileged secrets.
- Configure automated deployment from the main branch only after CI checks pass, if feasible.
- Include a README with local setup, Supabase setup, migrations, user creation, local run/build commands, deployment steps, PWA installation, backup/export, and common troubleshooting.
- Do not claim the app has deployed unless the deployment has actually been performed and verified.
- Free-tier services have quotas, availability limitations, and may pause inactive projects. Document these limitations and the process for restoring service.
- Set no paid plan or service by default. Ask for explicit approval before introducing any paid dependency or cloud service.

## 10. Recommended project organization

Use a small, understandable structure. Adapt it to Flutter conventions without excessive abstraction:

```text
lib/
  main.dart
  app.dart
  core/
    config/
    errors/
    utils/
  features/
    auth/
      data/
      presentation/
    dashboard/
      data/
      presentation/
    parking/
      data/
      domain/
      presentation/
  shared/
    widgets/
supabase/
  migrations/
  config.toml                 # only if using Supabase CLI config
test/
  core/
  features/
docs/
  architecture.md
  deployment.md
  security.md
```

Keep expiry calculation in a small, pure, unit-tested service. Keep Supabase queries out of widget build methods. Avoid building a generic framework for a tiny app.

## 11. Testing and acceptance criteria

The first release is complete only when these checks pass:

### Functional
- User can sign in and sign out.
- User can capture a photo or choose a file.
- User can preview, retake, and upload a photo.
- User can manually enter and review a vehicle registration without any
  image-processing initialization.
- User can select entry date/time and all four duration units.
- Expiry preview matches the saved database timestamp.
- Active/expired status changes correctly at the expiry boundary.
- User can search and view historical sessions.
- User can edit/delete authorized sessions.
- Loading, empty, validation, permission-denied, network, and upload-failure states are handled.

### Duration unit tests
At minimum test:
- 30 minutes added correctly.
- Multiple hours added correctly.
- One and multiple calendar days.
- One month from a mid-month date.
- January 31 plus one month clamps to the last valid February date.
- Leap-year February.
- December-to-January rollover.
- Positive integer validation and maximum duration.
- Expiry boundary: just before, exactly at, and just after expiry.
- UTC storage/local display behavior.
- Daylight-saving edge cases where supported.

### Security
- Unauthenticated users cannot access parking data or private photos.
- A tenant member cannot access another tenant's sessions/photos.
- A regular member cannot change a session's tenant or creator or grant a Super Admin role.
- A database-provisioned Super Admin can access all tenant sessions/photos and create tenants for existing Auth accounts.
- No service-role key appears in source, browser bundles, or logs.
- RLS is enabled and tested.
- Storage bucket is private.

### Cross-browser/PWA
- App is usable in desktop Chrome/Edge.
- App is usable in Android Chrome.
- App is usable in iPhone Safari.
- Add to Home Screen/Install App works where supported.
- Camera permissions and file-upload fallback are tested.
- Layout is usable on small screens.
- App works over HTTPS.
- Refreshing or reopening the app does not break navigation or authentication unexpectedly.

### Quality gates
After each phase, run:
- `dart format .`
- `flutter analyze`
- `flutter test`

If the project uses additional test commands, document them. Fix failures before advancing. Report actual command results; do not claim tests passed if they were not run.

## 12. Copilot workflow — implement one phase at a time

Do not generate the entire app in a single uncontrolled change. Use the phases below.

### Phase 1 — Inspect and plan
- Inspect the repository and installed Flutter/Dart versions.
- If the repository is empty, scaffold Flutter Web.
- Propose the folder structure, packages, architecture, and PWA approach.
- Identify any uncertainties before editing.
- Do not add paid services.

### Phase 2 — Foundation and PWA
- Create responsive app shell, theme, routing, loading/error components, PWA metadata, and icons.
- Verify local web launch.
- Run quality gates.

### Phase 3 — Supabase and security
- Add Supabase initialization.
- Create migrations for `parking_sessions`, tenant workspaces/memberships, constraints, indexes, RLS, and private storage policies. Backfill existing users and sessions without changing session ownership or photo paths.
- Add a database-backed Super Admin role and a guarded tenant-creation operation; keep Auth-user creation outside the browser.
- Implement sign-in/sign-out and explain initial account setup.
- Add repository tests or practical verification steps.
- Never bypass RLS.
- Run quality gates.

### Phase 4 — Parking domain and duration service
- Implement data models and a pure expiry-calculation service.
- Use calendar arithmetic for days/months, with month-end clamping.
- Add unit tests for edge cases before connecting the UI.
- Run quality gates.

### Phase 5 — Parking entry and photos
- Implement the form, camera/file fallback, preview/retake, plate input, duration controls, expiry preview, save and cleanup/error handling.
- Verify database and Storage permissions.
- Run quality gates.

### Phase 6 — Manual registration and photo-flow hardening
- Verify the Phase 5 camera and file-selection flow returns a photo or a clear
  recoverable error and never remains indefinitely loading.
- Keep manual registration entry, normalization, validation, and saving
  independent of photo capture, file selection, preview, replacement, and
  upload.
- Add regression tests for manual registration, invalid input, photo
  selection/capture, preview, retake/replace, upload failure, cleanup retry,
  duration calculation, and save behavior without image processing.
- Do not add OCR, automatic registration recognition, image-processing
  services, or new backend infrastructure.
- Do not change Supabase schema, authentication, RLS, Storage policies,
  duration calculations, or the session-first save flow unless a demonstrated
  requirement is approved.
- Run quality gates and document limitations and the actual device/browser
  checks performed.

### Phase 7 — Dashboard, history, edit/delete
- Implement lists, search, status, detail view, editing, and deletion.
- Add tenant selection and a role-gated Super Admin screen for creating tenants with existing Auth accounts as owners.
- Handle loading, empty, and failure states.
- Run quality gates.

### Phase 8 — Browser/PWA testing
- Test responsive UI, camera permissions, manual registration, file upload,
  home-screen installation, refresh, and authentication on desktop, Android,
  and iPhone.
- Document anything that cannot be tested in the current environment.
- Fix issues and run quality gates.

### Phase 9 — Deployment and handover
- Document Supabase project setup, environment config, migration application,
  account setup, static hosting, HTTPS, deployment, PWA installation,
  backups, and troubleshooting.
- Add CI checks and deployment automation only when simple and reliable.
- Do not deploy automatically to a paid plan.
- Verify the live site if deployment access is available.
- Provide a final summary of files changed, commands run, test results, known limitations, and manual steps still required.

## 13. Instructions for Copilot Agent mode

Follow these rules throughout the project:

1. At the start of each phase, present a short plan and list the files expected to change.
2. Implement only the current phase. Do not silently move on to later phases.
3. Inspect current package documentation/API signatures rather than guessing.
4. Keep changes small and reviewable.
5. Explain any new dependency and why Flutter built-ins are insufficient.
6. Do not introduce paid services, custom servers, native mobile targets,
   OCR or external image-recognition/processing services, or complex
   abstractions. Preserve the existing private Supabase vehicle-photo flow.
7. Never hardcode credentials or secrets.
8. Never disable security controls to get a passing test.
9. Run formatter, analyzer, and tests after meaningful changes.
10. If a command cannot run, state why and provide the exact command for the developer to run.
11. Do not claim deployment, device testing, or successful verification unless actually performed.
12. At the end of each phase, summarize files changed, commands run, results, remaining issues, and the next phase.
13. Ask before making a material architecture change or introducing a paid service.
14. Prefer a boring, reliable, easy-to-maintain solution over clever abstractions.

## 14. Definition of done

The project is done when the authenticated PWA is hosted over HTTPS, can be
added to an Android and iPhone home screen, captures/uploads a vehicle photo,
accepts manually entered plate details and an allowed duration in
minutes/hours/days/months, calculates expiry correctly, shows active/expired
sessions, supports tenant-scoped search and history, provides a database-role
gated Super Admin panel for tenant creation, enforces tenant and private-photo
security in Supabase, passes documented tests, and includes
setup/deployment/backup documentation.

Begin with **Phase 1 only**. Inspect the repository and environment, propose the plan, and wait for approval before making substantial changes.
