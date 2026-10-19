# Applies a single additive local PostgreSQL migration file without rotating
# the parking_api role password or rewriting local-api/.env.local-api.
# Usage:
#   $env:PARKING_POSTGRES_PASSWORD = '<postgres1 password>'
#   .\scripts\apply-local-migration.ps1 -MigrationFile local-api\migrations\002_parking_charges.sql

param(
  [Parameter(Mandatory)]
  [string]$MigrationFile
)

$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$psqlPath = 'C:\Program Files\PostgreSQL\16\bin\psql.exe'
$databaseName = 'parking_local'
$adminRole = 'postgres1'
$resolvedMigrationFile = Join-Path $repositoryRoot $MigrationFile

if (-not (Test-Path -LiteralPath $psqlPath)) {
  throw "PostgreSQL client not found at $psqlPath."
}
if (-not (Test-Path -LiteralPath $resolvedMigrationFile)) {
  throw "Migration file not found: $resolvedMigrationFile"
}

$adminPassword = $env:PARKING_POSTGRES_PASSWORD
if ([string]::IsNullOrWhiteSpace($adminPassword)) {
  $securePassword = Read-Host "Password for local PostgreSQL role $adminRole" -AsSecureString
  $passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
  try {
    $adminPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)
  }
  finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
  }
}
if ([string]::IsNullOrWhiteSpace($adminPassword)) {
  throw 'A local PostgreSQL password is required.'
}

try {
  $startInfo = [Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = $psqlPath
  $startInfo.UseShellExecute = $false
  $startInfo.RedirectStandardInput = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  $startInfo.ArgumentList.Add('--host=127.0.0.1')
  $startInfo.ArgumentList.Add('--port=5432')
  $startInfo.ArgumentList.Add("--username=$adminRole")
  $startInfo.ArgumentList.Add("--dbname=$databaseName")
  $startInfo.ArgumentList.Add('--no-psqlrc')
  $startInfo.ArgumentList.Add('--set=ON_ERROR_STOP=1')
  $startInfo.ArgumentList.Add('--file=-')
  $startInfo.Environment['PGPASSWORD'] = $adminPassword

  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $startInfo
  if (-not $process.Start()) {
    throw 'Could not start the PostgreSQL client.'
  }

  $stdoutTask = $process.StandardOutput.ReadToEndAsync()
  $stderrTask = $process.StandardError.ReadToEndAsync()
  $process.StandardInput.Write((Get-Content -LiteralPath $resolvedMigrationFile -Raw))
  $process.StandardInput.Close()
  $process.WaitForExit()
  $stdout = $stdoutTask.GetAwaiter().GetResult()
  $stderr = $stderrTask.GetAwaiter().GetResult()
  if ($process.ExitCode -ne 0) {
    throw "Migration failed: $($stderr.Trim())"
  }

  Write-Output $stdout.Trim()
  Write-Output "Applied $MigrationFile to $databaseName."
}
finally {
  Remove-Item Env:PARKING_POSTGRES_PASSWORD -ErrorAction SilentlyContinue
  $adminPassword = $null
}
