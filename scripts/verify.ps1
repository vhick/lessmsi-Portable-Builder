param([Parameter(Mandatory=$true)][string]$AppRoot)
$ErrorActionPreference='Stop'
$required = @('lessmsiPortable.exe','App/LessMsi/lessmsi-gui.exe','App/LessMsi/lessmsi.exe','App/AppInfo/appinfo.ini','App/AppInfo/appicon.ico','Data/Settings','Other/Source/BUILD-INFO.txt')
foreach ($path in $required) {
  $full = Join-Path $AppRoot $path
  if (-not (Test-Path $full)) { throw "Missing required portable file or folder: $path" }
}
if (Test-Path (Join-Path $AppRoot 'App/LessMsi/AddWindowsExplorerShortcut.exe')) { throw 'Registry registration helper must be excluded.' }
$ini=Get-Content -Raw -Encoding UTF8 (Join-Path $AppRoot 'App/AppInfo/appinfo.ini')
foreach($needle in @('Start=lessmsiPortable.exe','AppID=lessmsiPortable','Category=Utilities')) { if (-not $ini.Contains($needle)) { throw "Missing PortableApps metadata: $needle" } }
foreach($size in @(16,32,75,128,256)) { if (-not (Test-Path (Join-Path $AppRoot "App/AppInfo/appicon_$size.png"))) { throw "Missing icon png $size" } }
Write-Host 'Verified launcher, binaries, AppInfo metadata, icons, and protected Data directory.'
