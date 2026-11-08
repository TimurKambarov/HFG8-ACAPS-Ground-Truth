# Starts app-mobile with real login against the project's Supabase.
# Reads only SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY from ../API.key.
# The secret key is never passed to the app.
#
#   ./app-mobile/run.ps1                 # Flutter picks the device (asks if there are several)
#   ./app-mobile/run.ps1 -Device edge    # web, in Microsoft Edge
#   ./app-mobile/run.ps1 -Device 192.168.1.23:41234   # phone over wireless debugging (see README)
#
# Without these keys (plain `flutter run`) the app still works, with demo users only.
param([string]$Device = '')

$keys = @{}
Get-Content (Join-Path $PSScriptRoot '..\API.key') | ForEach-Object {
  if ($_ -match '^\s*([A-Z_]+)\s*=\s*(.+?)\s*$') { $keys[$Matches[1]] = $Matches[2] }
}
if (-not $keys['SUPABASE_URL'] -or -not $keys['SUPABASE_PUBLISHABLE_KEY']) {
  Write-Error 'API.key needs SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY.'; exit 1
}

$flutterArgs = @('run')
if ($Device) { $flutterArgs += @('-d', $Device) }
$flutterArgs += "--dart-define=SUPABASE_URL=$($keys['SUPABASE_URL'])"
$flutterArgs += "--dart-define=SUPABASE_PUBLISHABLE_KEY=$($keys['SUPABASE_PUBLISHABLE_KEY'])"

# Run from app-mobile/, then return the terminal to where it was.
Push-Location $PSScriptRoot
try { flutter @flutterArgs } finally { Pop-Location }
