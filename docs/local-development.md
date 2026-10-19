# Local PostgreSQL development

The app has an opt-in development mode for one PostgreSQL database on the
developer's computer. It does not use Docker, Supabase CLI, a hosted Supabase
development project, or production data. The deployed/default architecture
remains Supabase; the local API is never deployed.

## Prerequisites

- PostgreSQL 16 running on `127.0.0.1:5432`.
- A local PostgreSQL role named `postgres1` that can create/use the database
  and manage the local API role.
- Node.js 22 or later and the stable Flutter SDK with web support.

If `parking_local` does not exist, create it once from PowerShell. `psql`
prompts for the local `postgres1` password:

```powershell
& 'C:\Program Files\PostgreSQL\16\bin\psql.exe' `
  --host=127.0.0.1 --port=5432 --username=postgres1 --dbname=postgres `
  --command='CREATE DATABASE parking_local OWNER postgres1;'
```

Do not run the `CREATE DATABASE` command if `parking_local` already exists.
Use this database only for local app development; do not copy production data
into it.

## Initialize and seed

From the repository root:

```powershell
.\scripts\setup-local-postgres.ps1
Push-Location .\local-api
npm ci
npm run seed:local-admin
Pop-Location
```

The setup script prompts for the local PostgreSQL password, applies the
local-only schema, creates a least-privilege `parking_api` role, generates a
local signing secret, and writes `local-api\.env.local-api`. That file and the
local photo directory are ignored by Git. Do not share or commit them.

The seed command creates only the synthetic local Super Admin
`local-admin@parking.test` and prints a one-time password when it is first
created. Save that password privately and change it at first sign-in. Running
the seed command again does not show or reset an existing password.

## Run the app

Start the API in one PowerShell terminal:

```powershell
Push-Location .\local-api
npm start
```

In a second terminal, run Flutter with the explicit local backend selection:

```powershell
flutter run -d chrome --web-hostname localhost --web-port 5211 `
  --dart-define=PARKING_BACKEND=local `
  --dart-define=PARKING_LOCAL_API_URL=http://127.0.0.1:8765
```

Open the localhost URL printed by Flutter. The API listens only on
`127.0.0.1`; it is not reachable from a phone or another computer on the LAN.
The browser's local sign-in token is held in memory, so refreshing the page
requires signing in again. Parking records and photos stay in the local
database and ignored `local-api\storage\` directory.

Stop the API with Ctrl+C. Without `PARKING_BACKEND=local`, the app follows its
default Supabase path and requires the Supabase public URL and publishable key.
The local mode does not contact Supabase and does not verify Supabase RLS or
hosted Storage policies.

## Local API checks

From `local-api`:

```powershell
npm test
npm run test:local-api
```

The integration test uses the local PostgreSQL database and removes its
temporary rows and photos. It is not a production-data or hosted Supabase
test.
