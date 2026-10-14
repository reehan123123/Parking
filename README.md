# Parking Management PWA

Private parking management Progressive Web App built with Flutter Web. The
application will use Supabase for authentication, PostgreSQL data, and private
photo storage, and will target Cloudflare Pages for static hosting.

## Current status

Phase 2 is complete: the responsive Flutter Web shell, placeholder navigation,
reusable UI state widgets, and PWA metadata are in place. Supabase
configuration, migrations, authentication, and parking features remain
intentionally deferred to their specified phases.

## Local development

The project requires the stable Flutter SDK with web support. From the
repository root:

```powershell
flutter pub get
dart format .
flutter analyze
flutter test
flutter run -d chrome
```

The local environment used for Phase 1 has Flutter 3.47.7 and Dart 3.13.5.
If `flutter` and `dart` are not on `PATH`, invoke them from the installed
Flutter SDK's `bin` directory or add that directory to `PATH`.

## Scope guardrails

The first release will remain web-only and free-tier friendly. It will not
include native app builds, OCR, payments, public self-registration, custom
backend services, or full offline operation.
