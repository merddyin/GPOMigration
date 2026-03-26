# OfficeIMO Plugin — Load.ps1
# Loads OfficeIMO.Excel and its dependency DLLs from plugins/OfficeIMO/lib/ into the
# PowerShell session using Assembly.LoadFrom. Skips any assembly whose short name is
# already loaded to avoid duplicate-load conflicts.
#
# Called by PostLoad.ps1 via Invoke-Command -NoNewScope; runs in module scope.
# Sets $script:OfficeIMOLoaded = $true on success.

$libPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'lib'

if (-not (Test-Path $libPath)) {
    throw "OfficeIMO plugin: lib directory not found at '$libPath'. Re-run the NuGet restore described in plugins/OfficeIMO/README.md."
}

# Load in dependency order so that OfficeIMO.Excel is last (depends on the others)
$loadOrder = @(
    'Microsoft.Bcl.AsyncInterfaces.dll',
    'DocumentFormat.OpenXml.dll',
    'SixLabors.ImageSharp.dll',
    'SixLabors.Fonts.dll',
    'OfficeIMO.Excel.dll'
)

$alreadyLoaded = [System.AppDomain]::CurrentDomain.GetAssemblies() |
    ForEach-Object { $_.GetName().Name }

$ordered = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

foreach ($dllName in $loadOrder) {
    $ordered.Add($dllName) | Out-Null
    $dllPath = Join-Path $libPath $dllName
    if (-not (Test-Path $dllPath)) {
        throw "OfficeIMO plugin: required DLL not found: '$dllPath'. Re-run the NuGet restore described in plugins/OfficeIMO/README.md."
    }
    $asmName = [System.IO.Path]::GetFileNameWithoutExtension($dllName)
    if ($asmName -in $alreadyLoaded) {
        Write-Verbose "OfficeIMO plugin: '$asmName' already loaded in session; skipping."
    } else {
        [System.Reflection.Assembly]::LoadFrom($dllPath) | Out-Null
        Write-Verbose "OfficeIMO plugin: loaded '$dllName'."
    }
}

# Load any additional DLLs present in lib/ that were not in the explicit order list
foreach ($dll in (Get-ChildItem $libPath -Filter '*.dll')) {
    if (-not $ordered.Contains($dll.Name)) {
        $asmName = [System.IO.Path]::GetFileNameWithoutExtension($dll.Name)
        if ($asmName -notin $alreadyLoaded) {
            [System.Reflection.Assembly]::LoadFrom($dll.FullName) | Out-Null
            Write-Verbose "OfficeIMO plugin: loaded '$($dll.Name)'."
        }
    }
}

$script:OfficeIMOLoaded = $true
Write-Verbose "OfficeIMO plugin loaded successfully."
