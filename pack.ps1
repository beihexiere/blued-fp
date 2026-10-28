param(
    [Parameter(Mandatory = $true)]
    [string] $Dylib,

    [string] $Source = "",
    [string] $Out    = "E:\tare_project\Blued\out\Blued_plugin.ipa"
)

$ErrorActionPreference = "Stop"

# auto-detect the extracted app dir (folder containing Payload\Blued.app)
if ([string]::IsNullOrWhiteSpace($Source)) {
    $candidates = Get-ChildItem -Path "E:\tare_project\Blued" -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName "Payload\Blued.app") }
    if (-not $candidates) { throw "no folder with Payload\Blued.app found under E:\tare_project\Blued" }
    $Source = $candidates[0].FullName
    Write-Host "source: $Source"
}

$sevenZip = "C:\Program Files\7-Zip\7z.exe"
if (-not (Test-Path $sevenZip)) { throw "7z not found: $sevenZip" }
if (-not (Test-Path $Dylib)) { throw "dylib not found: $Dylib" }
if (-not (Test-Path (Join-Path $Source "Payload\Blued.app"))) { throw "bad source layout: $Source" }

$buildDir = "E:\tare_project\Blued\build"
$stage    = Join-Path $buildDir "stage"
$backup   = Join-Path $buildDir "bluedhookRaw.original.dylib"

if (-not (Test-Path $buildDir)) { New-Item -ItemType Directory -Path $buildDir | Out-Null }

# backup original injected dylib (once)
$origDylib = Join-Path $Source "Payload\Blued.app\Frameworks\bluedhookRaw.dylib"
if (-not (Test-Path $backup) -and (Test-Path $origDylib)) {
    Copy-Item $origDylib $backup
    Write-Host "backup original dylib -> $backup"
}

# rebuild staging dir
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Path $stage | Out-Null
Copy-Item (Join-Path $Source "Payload") -Destination $stage -Recurse -Force

# overwrite the plugin dylib (reuses the existing LC_LOAD_DYLIB slot, no Mach-O patching)
$target = Join-Path $stage "Payload\Blued.app\Frameworks\bluedhookRaw.dylib"
Copy-Item $Dylib $target -Force
Write-Host ("replaced dylib: {0:N0} bytes" -f (Get-Item $target).Length)

# drop stale signature dirs
Get-ChildItem -Path (Join-Path $stage "Payload") -Recurse -Directory -Filter "_CodeSignature" -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force

$outDir = Split-Path $Out -Parent
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
if (Test-Path $Out) { Remove-Item $Out -Force }

Push-Location $stage
try {
    & $sevenZip a -tzip -mx=1 -y $Out "Payload" | Out-Null
} finally {
    Pop-Location
}

$size = (Get-Item $Out).Length
Write-Host ("done: {0}  ({1:N1} MB)" -f $Out, ($size / 1MB))
Write-Host "next: import this ipa into QuanNengQian (全能签) and sign/install."
