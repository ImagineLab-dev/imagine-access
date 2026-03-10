$ErrorActionPreference = 'Stop'

$envFile = Join-Path $PWD '.env'
if (-not (Test-Path $envFile)) {
  Write-Error '.env no encontrado en la raíz del proyecto.'
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

if ([string]::IsNullOrWhiteSpace($supabaseUrl) -or [string]::IsNullOrWhiteSpace($anonKey)) {
  Write-Error 'Faltan SUPABASE_URL o SUPABASE_ANON_KEY en .env'
}

$headers = @{
  'apikey' = $anonKey
  'Authorization' = "Bearer $anonKey"
  'Content-Type' = 'application/json'
}

$tests = @(
  @{ Name = 'REST events'; Method = 'GET'; Url = "$supabaseUrl/rest/v1/events?select=id&limit=1"; Body = $null },
  @{ Name = 'Function login_device'; Method = 'POST'; Url = "$supabaseUrl/functions/v1/login_device"; Body = '{"alias":"health-check","pin":"0000"}' },
  @{ Name = 'Function create_event'; Method = 'POST'; Url = "$supabaseUrl/functions/v1/create_event"; Body = '{"name":"x","date":"2026-01-01T00:00:00Z","venue":"x"}' },
  @{ Name = 'Function ensure_profile'; Method = 'POST'; Url = "$supabaseUrl/functions/v1/ensure_profile"; Body = '{}' },
  @{ Name = 'Function validate_ticket'; Method = 'POST'; Url = "$supabaseUrl/functions/v1/validate_ticket"; Body = '{"method":"id","ticket_id":"00000000-0000-0000-0000-000000000000","notes":"health","device_id":"health","request_id":"00000000-0000-0000-0000-000000000000"}' }
)

$results = @()
foreach ($t in $tests) {
  try {
    if ($t.Method -eq 'GET') {
      $resp = Invoke-WebRequest -UseBasicParsing -Method GET -Uri $t.Url -Headers $headers -TimeoutSec 20
    } else {
      $resp = Invoke-WebRequest -UseBasicParsing -Method $t.Method -Uri $t.Url -Headers $headers -Body $t.Body -TimeoutSec 20
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

$results | Format-Table -AutoSize | Out-String | Write-Output

$hardFail = $results | Where-Object { $_.Status -eq $null }
if ($hardFail) {
  Write-Error 'Hay pruebas sin respuesta HTTP (fallo de conectividad real o DNS/red).'
}
