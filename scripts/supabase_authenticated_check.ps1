$ErrorActionPreference = 'Stop'

$envFile = Join-Path $PWD '.env'
if (-not (Test-Path $envFile)) {
  throw '.env no encontrado en la raíz del proyecto.'
}

$vars = @{}
Get-Content $envFile | ForEach-Object {
  $line = $_.Trim()
  if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) { return }
  $idx = $line.IndexOf('=')
  if ($idx -lt 1) { return }
  $key = $line.Substring(0, $idx).Trim()
  $val = $line.Substring($idx + 1).Trim().Trim('"')
  if ($key) { $vars[$key] = $val }
}

$supabaseUrl = $vars['SUPABASE_URL']
$anonKey = $vars['SUPABASE_ANON_KEY']
$testEmail = $vars['SUPABASE_TEST_EMAIL']
$testPassword = $vars['SUPABASE_TEST_PASSWORD']

if ([string]::IsNullOrWhiteSpace($supabaseUrl) -or [string]::IsNullOrWhiteSpace($anonKey)) {
  throw 'Faltan SUPABASE_URL o SUPABASE_ANON_KEY en .env'
}

$authHeaders = @{
  'apikey' = $anonKey
  'Content-Type' = 'application/json'
}

$accessToken = $null
$emailUsed = $null
$authDiagnostic = $null

if (-not [string]::IsNullOrWhiteSpace($testEmail) -and -not [string]::IsNullOrWhiteSpace($testPassword)) {
  try {
    $tokenBody = @{ email = $testEmail; password = $testPassword } | ConvertTo-Json -Compress
    $tokenResponse = Invoke-RestMethod -UseBasicParsing -Method POST -Uri "$supabaseUrl/auth/v1/token?grant_type=password" -Headers $authHeaders -Body $tokenBody -TimeoutSec 30
    if ($tokenResponse.access_token) {
      $accessToken = $tokenResponse.access_token
      $emailUsed = $testEmail
    }
  }
  catch {
    try {
      $signupBody = @{ email = $testEmail; password = $testPassword } | ConvertTo-Json -Compress
      $signupResponse = Invoke-RestMethod -UseBasicParsing -Method POST -Uri "$supabaseUrl/auth/v1/signup" -Headers $authHeaders -Body $signupBody -TimeoutSec 30
      if ($signupResponse.user -and -not $signupResponse.session) {
        $authDiagnostic = 'Cuenta de prueba creada/encontrada pero pendiente de confirmación de email. Confirma el correo para obtener JWT por password.'
      }
    }
    catch {
      # fallback below
    }
  }
}

if ([string]::IsNullOrWhiteSpace($accessToken)) {
  $stamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  $email = "healthcheck+$stamp@imagineaccess.local"
  $password = "Ia!$stamp`_A"

  $signupBody = @{ email = $email; password = $password } | ConvertTo-Json -Compress
  $signupResponse = Invoke-RestMethod -UseBasicParsing -Method POST -Uri "$supabaseUrl/auth/v1/signup" -Headers $authHeaders -Body $signupBody -TimeoutSec 30

  if ($signupResponse.session -and $signupResponse.session.access_token) {
    $accessToken = $signupResponse.session.access_token
    $emailUsed = $email
  }
}

if ([string]::IsNullOrWhiteSpace($accessToken)) {
  try {
    $tokenBody = @{ email = $email; password = $password } | ConvertTo-Json -Compress
    $tokenResponse = Invoke-RestMethod -UseBasicParsing -Method POST -Uri "$supabaseUrl/auth/v1/token?grant_type=password" -Headers $authHeaders -Body $tokenBody -TimeoutSec 30
    if ($tokenResponse.access_token) {
      $accessToken = $tokenResponse.access_token
      $emailUsed = $email
    }
  }
  catch {
    # handled below
  }
}

if ([string]::IsNullOrWhiteSpace($accessToken)) {
  if (-not [string]::IsNullOrWhiteSpace($authDiagnostic)) {
    throw $authDiagnostic
  }
  throw 'No se pudo obtener JWT. Define SUPABASE_TEST_EMAIL/SUPABASE_TEST_PASSWORD en .env o desactiva confirmación obligatoria para signup de pruebas.'
}

$userHeaders = @{
  'apikey' = $anonKey
  'Authorization' = "Bearer $accessToken"
  'Content-Type' = 'application/json'
}

$tests = @(
  @{ Name = 'Auth me'; Method = 'GET'; Url = "$supabaseUrl/auth/v1/user"; Body = $null },
  @{ Name = 'Function ensure_profile (auth)'; Method = 'POST'; Url = "$supabaseUrl/functions/v1/ensure_profile"; Body = '{}' },
  @{ Name = 'Function create_event (auth non-admin)'; Method = 'POST'; Url = "$supabaseUrl/functions/v1/create_event"; Body = '{"name":"auth-health","date":"2026-01-01T00:00:00Z","venue":"test"}' }
)

$results = @()
foreach ($t in $tests) {
  try {
    if ($t.Method -eq 'GET') {
      $resp = Invoke-WebRequest -UseBasicParsing -Method GET -Uri $t.Url -Headers $userHeaders -TimeoutSec 20
    } else {
      $resp = Invoke-WebRequest -UseBasicParsing -Method $t.Method -Uri $t.Url -Headers $userHeaders -Body $t.Body -TimeoutSec 20
    }
    $results += [pscustomobject]@{ Test = $t.Name; Status = $resp.StatusCode; Ok = $true }
  }
  catch {
    $status = $null
    if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
      $status = [int]$_.Exception.Response.StatusCode
    }
    $results += [pscustomobject]@{ Test = $t.Name; Status = $status; Ok = $false }
  }
}

Write-Output ("JWT obtenido para usuario: {0}" -f $emailUsed)
$results | Format-Table -AutoSize | Out-String | Write-Output
