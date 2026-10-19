$ErrorActionPreference = 'Stop'

$securePassword = Read-Host 'Enter the Supabase database password' -AsSecureString
if ($securePassword.Length -eq 0) {
    $securePassword.Dispose()
    throw 'The database password cannot be empty.'
}

$pointer = [IntPtr]::Zero
$plainPassword = $null

try {
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR(
        $securePassword
    )
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR(
        $pointer
    )

    [Environment]::SetEnvironmentVariable(
        'SUPABASE_DB_PASSWORD',
        $plainPassword,
        [EnvironmentVariableTarget]::User
    )
    $env:SUPABASE_DB_PASSWORD = $plainPassword

    Write-Warning (
        'Windows user environment variables are not encrypted secret storage. ' +
        'Processes running as your account can read this value.'
    )
    Write-Host (
        'SUPABASE_DB_PASSWORD is set for your Windows user and this PowerShell ' +
        'process. The value was not displayed.'
    )
}
finally {
    if ($pointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    }

    $plainPassword = $null
    $securePassword.Dispose()
}
