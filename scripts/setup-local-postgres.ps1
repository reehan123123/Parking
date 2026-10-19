$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$psqlPath = 'C:\Program Files\PostgreSQL\16\bin\psql.exe'
$databaseName = 'parking_local'
$adminRole = 'postgres1'
$environmentFile = Join-Path $repositoryRoot 'local-api\.env.local-api'
$migrationFile = Join-Path $repositoryRoot 'local-api\migrations\001_local_schema.sql'
$storageDirectory = Join-Path $repositoryRoot 'local-api\storage\vehicle-photos'

if (-not (Test-Path -LiteralPath $psqlPath)) {
  throw "PostgreSQL client not found at $psqlPath."
}
if (-not (Test-Path -LiteralPath $migrationFile)) {
  throw 'The local PostgreSQL schema migration is missing.'
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

function Invoke-LocalPsql {
  param(
    [Parameter(Mandatory)]
    [string]$Database,
    [Parameter(Mandatory)]
    [string]$Sql,
    [switch]$TuplesOnly
  )

  $startInfo = [Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = $psqlPath
  $startInfo.UseShellExecute = $false
  $startInfo.RedirectStandardInput = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  $startInfo.ArgumentList.Add('--host=127.0.0.1')
  $startInfo.ArgumentList.Add('--port=5432')
  $startInfo.ArgumentList.Add("--username=$adminRole")
  $startInfo.ArgumentList.Add("--dbname=$Database")
  $startInfo.ArgumentList.Add('--no-psqlrc')
  $startInfo.ArgumentList.Add('--set=ON_ERROR_STOP=1')
  if ($TuplesOnly) {
    $startInfo.ArgumentList.Add('--tuples-only')
    $startInfo.ArgumentList.Add('--no-align')
  }
  $startInfo.ArgumentList.Add('--file=-')
  $startInfo.Environment['PGPASSWORD'] = $adminPassword

  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $startInfo
  if (-not $process.Start()) {
    throw 'Could not start the PostgreSQL client.'
  }

  $stdoutTask = $process.StandardOutput.ReadToEndAsync()
  $stderrTask = $process.StandardError.ReadToEndAsync()
  $process.StandardInput.Write($Sql)
  $process.StandardInput.Close()
  $process.WaitForExit()
  $stdout = $stdoutTask.GetAwaiter().GetResult()
  $stderr = $stderrTask.GetAwaiter().GetResult()
  if ($process.ExitCode -ne 0) {
    throw "Local PostgreSQL setup failed: $($stderr.Trim())"
  }

  return $stdout.Trim()
}

try {
  $databaseExists = Invoke-LocalPsql `
    -Database 'postgres' `
    -Sql "SELECT EXISTS (SELECT 1 FROM pg_database WHERE datname = '$databaseName');" `
    -TuplesOnly
  if ($databaseExists -ne 't') {
    throw "Database '$databaseName' does not exist. Create the empty local database first."
  }

  Invoke-LocalPsql `
    -Database $databaseName `
    -Sql (Get-Content -LiteralPath $migrationFile -Raw) | Out-Null

  $appPasswordBytes = [byte[]]::new(32)
  [Security.Cryptography.RandomNumberGenerator]::Fill($appPasswordBytes)
  $appPassword = [Convert]::ToBase64String($appPasswordBytes).
    TrimEnd('=').
    Replace('+', '-').
    Replace('/', '_')

  $signingSecretBytes = [byte[]]::new(32)
  [Security.Cryptography.RandomNumberGenerator]::Fill($signingSecretBytes)
  $signingSecret = [Convert]::ToBase64String($signingSecretBytes).
    TrimEnd('=').
    Replace('+', '-').
    Replace('/', '_')

  $roleSql = @"
DO `$setup`$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'parking_api') THEN
    EXECUTE format('ALTER ROLE parking_api WITH LOGIN PASSWORD %L', '$appPassword');
  ELSE
    EXECUTE format('CREATE ROLE parking_api WITH LOGIN PASSWORD %L', '$appPassword');
  END IF;
END
`$setup`$;
GRANT CONNECT ON DATABASE $databaseName TO parking_api;
GRANT USAGE ON SCHEMA core TO parking_api;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA core TO parking_api;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA core TO parking_api;
ALTER DEFAULT PRIVILEGES FOR ROLE $adminRole IN SCHEMA core
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO parking_api;
ALTER ROLE parking_api IN DATABASE $databaseName SET search_path TO core, pg_catalog;
ALTER ROLE parking_api IN DATABASE $databaseName SET statement_timeout TO '10s';
ALTER ROLE parking_api IN DATABASE $databaseName SET idle_in_transaction_session_timeout TO '30s';
"@
  Invoke-LocalPsql -Database $databaseName -Sql $roleSql | Out-Null

  $null = New-Item -ItemType Directory -Path $storageDirectory -Force
  $apiUrl = 'http://127.0.0.1:8765'
  $environmentContents = @(
    "PARKING_LOCAL_DATABASE_URL=postgresql://parking_api:$appPassword@127.0.0.1:5432/$databaseName"
    "PARKING_LOCAL_API_SIGNING_SECRET=$signingSecret"
    'PARKING_LOCAL_API_HOST=127.0.0.1'
    'PARKING_LOCAL_API_PORT=8765'
    "PARKING_LOCAL_API_URL=$apiUrl"
    "PARKING_LOCAL_STORAGE_DIR=$storageDirectory"
  )
  [IO.File]::WriteAllLines(
    $environmentFile,
    $environmentContents,
    [Text.UTF8Encoding]::new($false)
  )
  Write-Output "Local database schema and least-privilege API role are ready."
  Write-Output "Environment file created at $environmentFile (ignored by Git)."
}
finally {
  Remove-Item Env:PARKING_POSTGRES_PASSWORD -ErrorAction SilentlyContinue
  $adminPassword = $null
  $appPassword = $null
  $signingSecret = $null
}
