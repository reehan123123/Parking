# Parking UI Playwright resources

These Python Playwright scripts exercise the deployed Flutter UI. They never
write directly to Supabase. Credentials are read from environment variables or
prompted at runtime and are not saved in this folder.

Text entry uses keyboard events for Flutter Web semantics. Each authenticated
run attempts to sign out through the app. A registered device slot may remain
under the configured device-session policy, so repeated automation runs can
reach the account limit. If blocked, remove stale test sessions through the
app's device-management UI before retrying sign-in.

## Setup

From the repository root in PowerShell:

```powershell
python -m pip install -r .\playwright\requirements.txt
python -m playwright install chromium
$env:PARKING_BASE_URL = "https://parking-85u.pages.dev/"
$env:PARKING_USERNAME = Read-Host "Test account email"
$secret = Read-Host "Test account password" -AsSecureString
$pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
try {
    $env:PARKING_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    python .\playwright\check_login.py
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    Remove-Item Env:PARKING_PASSWORD -ErrorAction SilentlyContinue
}
```

The scripts also prompt for credentials when the environment variables are not
set. For repeat use, `run.ps1` prompts for the password without echoing it.

## Scenarios

| Script | Purpose |
| --- | --- |
| `check_login.py` | Sign in and verify the tenant app shell is available. |
| `add_parking.py` | Add one clearly marked `PWTEST...` record. |
| `edit_parking.py` | Edit a marked test record by plate. |
| `delete_parking.py` | Delete one marked test record after explicit confirmation. |
| `seed_dummy_records.py` | Add a persistent batch of mixed paid/partial/unpaid records (default: 20). |
| `crud_smoke.py` | Add, edit, verify, then delete one temporary marked record. |

Examples:

```powershell
python .\playwright\seed_dummy_records.py --count 20 --confirm-account $env:PARKING_USERNAME
python .\playwright\crud_smoke.py --confirm-account $env:PARKING_USERNAME
python .\playwright\add_parking.py --confirm-account $env:PARKING_USERNAME
python .\playwright\edit_parking.py --plate PWTEST261022132401 --total-charge 150 --paid-amount 50 --confirm-account $env:PARKING_USERNAME
python .\playwright\delete_parking.py --plate PWTEST261022132401 --confirm-account $env:PARKING_USERNAME --confirm-delete
```

`seed_dummy_records.py` leaves its records in the selected tenant. Each row
uses a unique plate beginning with `PWTEST`; the script does not remove prior
data. `crud_smoke.py` removes only the temporary row it created. Edit and
delete scripts reject plates without the `PWTEST` prefix. Mutating scripts
require `--confirm-account` to exactly match the signed-in email; deletion
also requires `--confirm-delete`.

The app must have an active tenant and the account must have Add, Edit, and
Delete permissions for the corresponding scenarios. The test contact number
used by the seed script is a syntactically valid placeholder; no SMS is sent.
