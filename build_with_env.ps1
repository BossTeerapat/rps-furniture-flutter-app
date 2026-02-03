param(
    [string]$EnvPath = ".env",
    [switch]$Install
)

# Read .env lines, ignore comments and empty lines
if (-not (Test-Path $EnvPath)) {
    Write-Error ".env file not found at path: $EnvPath"
    exit 2
}

$lines = Get-Content $EnvPath | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not ($_ -like "#*") }
if (-not $lines) {
    Write-Host "No env entries found in $EnvPath"
}

# Build argument list for flutter
$dartDefineArgs = @()
foreach ($line in $lines) {
    # Support KEY=VALUE pairs only
    if ($line -match "^([^=]+)=(.*)$") {
        $k = $matches[1].Trim()
        $v = $matches[2].Trim()
        # Escape any double quotes in value
        $v = $v -replace '"', '""'
        $arg = "--dart-define=$k=$v"
        Write-Host "Will inject: $k"
        $dartDefineArgs += $arg
    } else {
        Write-Host "Skipping invalid line: $line"
    }
}

# Common flutter build args
$buildArgs = @('build','apk','--release') + $dartDefineArgs

Write-Host "Running: flutter $($buildArgs -join ' ')"

# Run flutter clean then pub get then build using Start-Process to avoid quoting issues
$tools = @(
    @{cmd='flutter'; args=@('clean')},
    @{cmd='flutter'; args=@('pub','get')},
    @{cmd='flutter'; args=$buildArgs}
)

foreach ($t in $tools) {
    Write-Host "\n==> Running: $($t.cmd) $($t.args -join ' ')"
    $proc = Start-Process -FilePath $t.cmd -ArgumentList $t.args -NoNewWindow -Wait -PassThru -WindowStyle Hidden
    if ($proc.ExitCode -ne 0) {
        Write-Error "Command failed: $($t.cmd) $($t.args -join ' '), ExitCode=$($proc.ExitCode)"
        exit $proc.ExitCode
    }
}

# Optionally install on connected device
if ($Install) {
    $apkPath = "build\app\outputs\flutter-apk\app-release.apk"
    if (-not (Test-Path $apkPath)) {
        Write-Error "APK not found at $apkPath"
        exit 3
    }
    Write-Host "Installing APK: $apkPath"
    $adbProc = Start-Process -FilePath 'adb' -ArgumentList @('install','-r',$apkPath) -NoNewWindow -Wait -PassThru
    if ($adbProc.ExitCode -ne 0) {
        Write-Error "adb install failed with ExitCode $($adbProc.ExitCode)"
        exit $adbProc.ExitCode
    }
    Write-Host "Install finished."
}

Write-Host "Done."
