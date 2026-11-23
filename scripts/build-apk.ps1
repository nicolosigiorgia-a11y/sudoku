param(
  [switch]$SkipBuild,
  [string]$SupabaseUrl = '',
  [string]$SupabaseKey = '',
  [string]$ApiBaseUrl = ''
)

# I comandi nativi (Flutter/Gradle) scrivono avvisi su stderr: non devono
# interrompere la build. Gli errori reali sono gestiti con $LASTEXITCODE.
$ErrorActionPreference = 'Continue'

$flutterBat = ''
if ($env:FLUTTER_HOME) {
  $candidate = Join-Path $env:FLUTTER_HOME 'bin\flutter.bat'
  if (Test-Path $candidate) { $flutterBat = $candidate }
}
if (-not $flutterBat -and (Test-Path 'C:\src\flutter\bin\flutter.bat')) {
  $flutterBat = 'C:\src\flutter\bin\flutter.bat'
}
if (-not $flutterBat) {
  $inPath = Get-Command flutter.bat -ErrorAction SilentlyContinue
  if ($inPath) { $flutterBat = $inPath.Source }
}
if (-not $flutterBat) {
  $userFlutter = Join-Path $env:USERPROFILE 'flutter'
  if (Test-Path $userFlutter) {
    $found = Get-ChildItem $userFlutter -Filter 'flutter.bat' -Recurse -Depth 2 -File -ErrorAction SilentlyContinue |
      Select-Object -First 1 -ExpandProperty FullName
    if ($found) { $flutterBat = $found }
  }
}
if (-not (Test-Path $flutterBat)) {
  throw "Flutter non trovato. Imposta FLUTTER_HOME oppure aggiungi flutter.bat al PATH."
}

$root = Split-Path -Parent $PSScriptRoot
$appDir = Join-Path $root 'app'

# app_src/ è la fonte del codice Dart; la configurazione Android resta in app/android.
Copy-Item (Join-Path $root 'app_src\lib') -Destination $appDir -Recurse -Force
Copy-Item (Join-Path $root 'app_src\test') -Destination $appDir -Recurse -Force
Copy-Item (Join-Path $root 'app_src\pubspec.yaml') -Destination $appDir -Force
Copy-Item (Join-Path $root 'app_src\assets') -Destination $appDir -Recurse -Force

Set-Location $appDir
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
& $flutterBat --no-version-check pub get
& $flutterBat --no-version-check test
if ($LASTEXITCODE -ne 0) { throw 'I test Flutter non passano: build interrotto.' }
if (-not $SkipBuild) {
  $buildArgs = @('--no-version-check', 'build', 'apk', '--release')
  if ($SupabaseUrl.Trim()) { $buildArgs += "--dart-define=SUPABASE_URL=$($SupabaseUrl.Trim())" }
  if ($SupabaseKey.Trim()) { $buildArgs += "--dart-define=SUPABASE_KEY=$($SupabaseKey.Trim())" }
  if ($ApiBaseUrl.Trim()) { $buildArgs += "--dart-define=API_BASE_URL=$($ApiBaseUrl.Trim())" }
  $displayArgs = $buildArgs | ForEach-Object {
    if ($_ -like '--dart-define=SUPABASE_KEY=*') { '--dart-define=SUPABASE_KEY=***' } else { $_ }
  }
  Write-Host "Build args: $($displayArgs -join ' ')"
  & $flutterBat @buildArgs
  if ($LASTEXITCODE -ne 0) { throw 'Build APK fallita.' }
  $apk = Join-Path $appDir 'build\app\outputs\flutter-apk\app-release.apk'
  $target = Join-Path $root 'AI-Sudoku-Cat-Tutor.apk'
  Copy-Item $apk $target -Force
  Write-Host "APK pronto: $target"
}
