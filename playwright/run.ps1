param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("check_login", "add_parking", "edit_parking", "delete_parking", "seed_dummy_records", "crud_smoke")]
    [string]$Scenario,
    [string[]]$Arguments = @()
)

$previousBaseUrl = $env:PARKING_BASE_URL
$previousUsername = $env:PARKING_USERNAME
$previousPassword = $env:PARKING_PASSWORD
$secretPointer = [IntPtr]::Zero

try {
    if ([string]::IsNullOrWhiteSpace($env:PARKING_BASE_URL)) {
        $baseUrl = Read-Host "Parking app URL (default: https://parking-85u.pages.dev/)"
        $env:PARKING_BASE_URL = if ([string]::IsNullOrWhiteSpace($baseUrl)) {
            "https://parking-85u.pages.dev/"
        } else {
            $baseUrl.Trim()
        }
    }
    if ([string]::IsNullOrWhiteSpace($env:PARKING_USERNAME)) {
        $env:PARKING_USERNAME = (Read-Host "Parking test account email").Trim()
    }
    if ([string]::IsNullOrWhiteSpace($env:PARKING_PASSWORD)) {
        $securePassword = Read-Host "Parking test account password" -AsSecureString
        $secretPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
        $env:PARKING_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($secretPointer)
    }

    $scriptPath = Join-Path $PSScriptRoot "$Scenario.py"
    & python $scriptPath @Arguments
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
finally {
    if ($secretPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($secretPointer)
    }
    if ($null -eq $previousBaseUrl) {
        Remove-Item Env:PARKING_BASE_URL -ErrorAction SilentlyContinue
    } else {
        $env:PARKING_BASE_URL = $previousBaseUrl
    }
    if ($null -eq $previousUsername) {
        Remove-Item Env:PARKING_USERNAME -ErrorAction SilentlyContinue
    } else {
        $env:PARKING_USERNAME = $previousUsername
    }
    if ($null -eq $previousPassword) {
        Remove-Item Env:PARKING_PASSWORD -ErrorAction SilentlyContinue
    } else {
        $env:PARKING_PASSWORD = $previousPassword
    }
}
