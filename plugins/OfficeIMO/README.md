# OfficeIMO Plugin

This plugin bundles [OfficeIMO.Excel](https://github.com/EvotecIT/OfficeIMO) and its
runtime dependencies so that Excel export/import is always available without requiring
the consumer to install anything separately.

## Bundled DLLs (`lib/`)

| Assembly | Source Package | License |
|---|---|---|
| OfficeIMO.Excel.dll | OfficeIMO.Excel (NuGet) | MIT |
| DocumentFormat.OpenXml.dll | DocumentFormat.OpenXml | MIT |
| SixLabors.ImageSharp.dll | SixLabors.ImageSharp | Apache 2.0 |
| SixLabors.Fonts.dll | SixLabors.Fonts | Apache 2.0 |
| Microsoft.Bcl.AsyncInterfaces.dll | Microsoft.Bcl.AsyncInterfaces | MIT |

## Refreshing the DLLs

Run the following from the repository root to re-download the latest compatible versions:

```powershell
$baseUrl  = 'https://api.nuget.org/v3-flatcontainer'
$libPath  = 'plugins\OfficeIMO\lib'
New-Item -ItemType Directory -Force -Path $libPath | Out-Null

$packages = [ordered]@{
    'OfficeIMO.Excel'               = $null   # $null = latest stable
    'DocumentFormat.OpenXml'        = $null
    'SixLabors.ImageSharp'          = $null
    'SixLabors.Fonts'               = $null
    'Microsoft.Bcl.AsyncInterfaces' = $null
}

foreach ($entry in $packages.GetEnumerator()) {
    $id  = $entry.Key
    $ver = $entry.Value
    if (-not $ver) {
        $ver = ((Invoke-RestMethod "$baseUrl/$($id.ToLower())/index.json").versions |
                Where-Object { $_ -notmatch '-' }) | Select-Object -Last 1
    }
    $zip  = Join-Path $env:TEMP "$id.$ver.zip"
    $xdir = Join-Path $env:TEMP "$id.$ver"
    Invoke-WebRequest "$baseUrl/$($id.ToLower())/$ver/$($id.ToLower()).$ver.nupkg" -OutFile $zip -UseBasicParsing
    Expand-Archive $zip $xdir -Force
    foreach ($tf in 'netstandard2.0','netstandard2.1','net6.0','net8.0') {
        $src = Join-Path $xdir "lib\$tf"
        if (Test-Path $src) {
            Get-ChildItem $src -Filter '*.dll' | Copy-Item -Destination $libPath -Force
            Write-Host "  $id $ver [$tf]"
            break
        }
    }
    Remove-Item $zip,$xdir -Recurse -Force -ErrorAction SilentlyContinue
}
```

## Version Constraints

- OfficeIMO.Excel targets **netstandard2.0**; compatible with PowerShell 7+.
- If `DocumentFormat.OpenXml` is already loaded in the session at a different version,
  a warning will appear during module import. Resolve by loading GPOMigration before
  other modules that depend on DocumentFormat.OpenXml.
