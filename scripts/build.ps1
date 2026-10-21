param([string]$ReleaseTag = 'latest')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$kit = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$work = Join-Path $kit '_work'
$dist = Join-Path $kit '_dist'
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }
New-Item -ItemType Directory -Force $work,$dist | Out-Null

if ($ReleaseTag -eq 'latest') {
    $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/activescott/lessmsi/releases/latest' -Headers @{ 'User-Agent'='lessmsiPortableBuilder' }
} else {
    if ($ReleaseTag -notmatch '^v?\d+\.\d+\.\d+$') { throw 'Release tag must be latest or a version like v2.12.9.' }
    if (-not $ReleaseTag.StartsWith('v')) { $ReleaseTag = 'v' + $ReleaseTag }
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/activescott/lessmsi/releases/tags/$ReleaseTag" -Headers @{ 'User-Agent'='lessmsiPortableBuilder' }
}
$tag = [string]$release.tag_name
if ($tag -notmatch '^v(\d+\.\d+\.\d+)$' -or $release.prerelease -or $release.draft) { throw "Not a stable vX.Y.Z release: $tag" }
$version = $Matches[1]
$assetName = "lessmsi-$tag.zip"
$assets = @($release.assets | Where-Object { $_.name -eq $assetName })
if ($assets.Count -ne 1) { throw "Could not find official '$assetName'. Available: $(@($release.assets | ForEach-Object name) -join ', ')" }
$asset = $assets[0]
$archive = Join-Path $work $assetName
Write-Host "Downloading official lessmsi $tag from $($asset.browser_download_url)"
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $archive -Headers @{ 'User-Agent'='lessmsiPortableBuilder' }
$actualHash = (Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant()
$pin = ''
if ($tag -eq 'v2.12.9') { $pin = '5b4e187e74b184ad3a63ccf06c3d17dae2b8c4b6c298a996dbd51a9f6db29d21' }
if ($asset.PSObject.Properties.Name -contains 'digest' -and $asset.digest -match '^sha256:([0-9a-fA-F]{64})$') {
    $pin = $Matches[1].ToLowerInvariant()
}
if ($pin -ne '' -and $actualHash -ne $pin) { throw "Official release checksum mismatch! expected $pin, received $actualHash" }
if ($pin -eq '') { Write-Warning "No trusted SHA-256 digest advertised for $tag; release fetched over HTTPS. Actual SHA-256: $actualHash" }
else { Write-Host "Official release SHA-256 verified: $actualHash" }

$extract = Join-Path $work 'official-release'
Expand-Archive -LiteralPath $archive -DestinationPath $extract -Force
$guiFound = @(Get-ChildItem -LiteralPath $extract -Filter 'lessmsi-gui.exe' -File -Recurse)
if ($guiFound.Count -ne 1) { throw "Expected one lessmsi-gui.exe, found $($guiFound.Count)." }
$officialBin = $guiFound[0].Directory.FullName
if (-not (Test-Path (Join-Path $officialBin 'lessmsi.exe'))) { throw 'Missing official lessmsi.exe CLI alongside GUI.' }

$source = Join-Path $work 'upstream-source'
& git clone --quiet --depth 1 --branch $tag 'https://github.com/activescott/lessmsi.git' $source
if ($LASTEXITCODE -ne 0) { throw "Failed to clone upstream $tag" }
& python (Join-Path $kit 'scripts/patch_source.py') $source $version
if ($LASTEXITCODE -ne 0) { throw 'Source patch validation failed.' }

$solution = Join-Path $source 'src/LessMsi.sln'
if (-not (Test-Path $solution)) { throw 'Upstream LessMsi.sln missing.' }
$nuget = Get-Command 'nuget.exe' -ErrorAction SilentlyContinue
if (-not $nuget) {
    $nugetPath = Join-Path $work 'nuget.exe'
    Invoke-WebRequest -Uri 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' -OutFile $nugetPath
} else { $nugetPath = $nuget.Source }
# lessmsi uses packages.config and a post-build xcopy pointing to
# $(SolutionDir)packages\libmspack4n.0.9.10\build\x86\mspack.dll.
# Restore to the same explicit folder and fail *before* compilation if absent.
$solutionDir = (Join-Path $source 'src') + '\'
$packagesDir = Join-Path $source 'src/packages'
& $nugetPath restore $solution -PackagesDirectory $packagesDir -NonInteractive -Verbosity quiet
if ($LASTEXITCODE -ne 0) { throw 'NuGet restore failed.' }
$nativeCab = Join-Path $packagesDir 'libmspack4n.0.9.10/build/x86/mspack.dll'
$managedCab = Join-Path $packagesDir 'libmspack4n.0.9.10/lib/net40/libmspackn.dll'
foreach ($dependency in @($nativeCab, $managedCab)) {
    if (-not (Test-Path -LiteralPath $dependency -PathType Leaf)) {
        throw "Required upstream NuGet dependency missing: $dependency"
    }
}
Write-Host "Verified restored native CAB extractor: $nativeCab"
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path $vswhere)) { throw 'Visual Studio vswhere.exe is unavailable on the runner.' }
$msbuildPaths = @(& $vswhere -latest -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\MSBuild.exe')
if ($msbuildPaths.Count -lt 1) { throw 'MSBuild.exe not found.' }
$msbuild = $msbuildPaths[0]
# The upstream GUI .csproj has a post-build xcopy using $(SolutionDir).
# When MSBuild is invoked on a project rather than on its .sln, SolutionDir
# otherwise defaults to a relative path and xcopy cannot find mspack.dll.
$solutionProperty = '/p:SolutionDir=' + $solutionDir
& $msbuild (Join-Path $source 'src/LessMsi.Gui/LessMsi.Gui.csproj') /m /p:Configuration=Release /p:Platform=x86 $solutionProperty /verbosity:minimal /nologo
if ($LASTEXITCODE -ne 0) { throw 'Upstream source build with portable settings patch failed.' }
$rebuiltNativeCab = Join-Path $source 'src/LessMsi.Gui/bin/Release/mspack.dll'
if (-not (Test-Path -LiteralPath $rebuiltNativeCab -PathType Leaf)) {
    throw 'Upstream GUI build succeeded but did not copy mspack.dll. Check the post-build event and SolutionDir.'
}

$compiled = @(Get-ChildItem -Path (Join-Path $source 'src/LessMsi.Gui/bin') -File -Filter 'lessmsi-gui.exe' -Recurse | Where-Object { $_.FullName -match '[\\/]Release[\\/]' })
if ($compiled.Count -ne 1) { throw "Could not locate exactly one patched GUI executable; found $($compiled.Count)." }

$parent = Join-Path $work 'lessmsiPortable'
$app = Join-Path $parent 'App/LessMsi'
$appInfo = Join-Path $parent 'App/AppInfo'
$settings = Join-Path $parent 'Data/Settings'
$sourceInfo = Join-Path $parent 'Other/Source'
New-Item -ItemType Directory -Force $app,$appInfo,$settings,$sourceInfo | Out-Null
Copy-Item -Path (Join-Path $officialBin '*') -Destination $app -Recurse -Force
Copy-Item -LiteralPath $compiled[0].FullName -Destination (Join-Path $app 'lessmsi-gui.exe') -Force
$coreDll = Join-Path $source 'src/LessMsi.Core/bin/Release/lessmsi.core.dll'
if (-not (Test-Path $coreDll)) { throw 'Rebuilt lessmsi.core.dll not found.' }
Copy-Item -LiteralPath $coreDll -Destination (Join-Path $app 'lessmsi.core.dll') -Force
# The GUI is rebuilt as x86. Bundle the matching native x86 CAB extractor
# from the restored official NuGet package, rather than depending on the
# release ZIP having a copy or on the runner's PATH.
Copy-Item -LiteralPath $rebuiltNativeCab -Destination (Join-Path $app 'mspack.dll') -Force
if (-not (Test-Path -LiteralPath (Join-Path $app 'libmspackn.dll'))) {
    Copy-Item -LiteralPath $managedCab -Destination (Join-Path $app 'libmspackn.dll') -Force
}
# Prevent manual execution of the Explorer registration helper as an extra defense.
$helper = Join-Path $app 'AddWindowsExplorerShortcut.exe'
if (Test-Path $helper) { Remove-Item -LiteralPath $helper -Force }

$icon = Join-Path $source 'src/LessMsi.Gui/Resources/LessmsiIcon.ico'
if (-not (Test-Path $icon)) { throw 'Official lessmsi icon missing in source tag.' }
Copy-Item $icon (Join-Path $appInfo 'appicon.ico')
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit 'scripts/create-icons.ps1') -IconPath $icon -OutputDir $appInfo
if ($LASTEXITCODE -ne 0) { throw 'Icon generation failed.' }

$appInfoText = @"
[Format]
Type=PortableApps.comFormat
Version=3.9

[Details]
Name=lessmsi Portable
AppID=lessmsiPortable
BaseAppName=lessmsi
Publisher=Scott Willeke (upstream) and community portable repackaging
Homepage=https://github.com/activescott/lessmsi
Category=Utilities
Description=View and extract Windows Installer MSI files
Language=Multilingual

[License]
Shareable=true
OpenSource=true
Freeware=true
CommercialUse=true

[Version]
PackageVersion=$version.0
DisplayVersion=$version

[Dependencies]
UsesDotNetVersion=4.8
Requires64bitOS=no
RequiresAdmin=no

[Control]
Icons=1
Start=lessmsiPortable.exe
"@
Set-Content -LiteralPath (Join-Path $appInfo 'appinfo.ini') -Value $appInfoText -Encoding UTF8

$csc = Join-Path $env:WINDIR 'Microsoft.NET/Framework/v4.0.30319/csc.exe'
if (-not (Test-Path $csc)) { throw 'Required .NET Framework C# compiler is missing.' }
& $csc /nologo /target:winexe /optimize+ /reference:System.Windows.Forms.dll /win32icon:$icon "/out:$(Join-Path $parent 'lessmsiPortable.exe')" (Join-Path $kit 'launcher/lessmsiPortable.cs')
if ($LASTEXITCODE -ne 0) { throw 'Portable launcher compilation failed.' }
Copy-Item (Join-Path $kit 'README.md') (Join-Path $sourceInfo 'BUILDER-README.md')
Copy-Item (Join-Path $kit 'patches/Settings.Designer.cs') (Join-Path $sourceInfo 'Settings.Designer.cs')
Copy-Item (Join-Path $kit 'launcher/lessmsiPortable.cs') (Join-Path $sourceInfo 'lessmsiPortable.cs')
Copy-Item (Join-Path $source 'src/LICENSE') (Join-Path $sourceInfo 'UPSTREAM-LICENSE.txt')
Set-Content -LiteralPath (Join-Path $sourceInfo 'BUILD-INFO.txt') -Value "upstream=$tag`nsha256=$actualHash`nbuilder=1.1`n" -Encoding UTF8
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit 'scripts/verify.ps1') -AppRoot $parent
if ($LASTEXITCODE -ne 0) { throw 'Portable package verification failed.' }
$zip = Join-Path $dist "lessmsiPortable-$version.zip"
Compress-Archive -LiteralPath $parent -DestinationPath $zip -CompressionLevel Optimal
Write-Host "PACKAGED: $zip"
Write-Host "SHA-256: $((Get-FileHash $zip -Algorithm SHA256).Hash)"
