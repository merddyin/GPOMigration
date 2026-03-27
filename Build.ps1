#Requires -Version 7.0
[CmdletBinding()]
param (
    [switch]$BuildModule,
    [switch]$TestBuildAndInstallModule,
    [switch]$UpdateRelease,
    [version]$NewVersion,
    [string]$ReleaseNotes,
    [switch]$UploadPSGallery,
    [switch]$CreatePSGalleryPackage,
    [string]$PSGalleryApiKey,
    [switch]$AddMissingCBH,
    [switch]$Test,
    [switch]$TestMetaOnly,
    [switch]$TestUnitOnly,
    [switch]$TestIntergrationOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ProjectRoot = $PSScriptRoot
$script:ManifestPath = Join-Path $script:ProjectRoot 'GPOMigration.psd1'
$script:ReleaseRoot = Join-Path $script:ProjectRoot 'release'
$script:ReleaseModuleRoot = Join-Path $script:ReleaseRoot 'GPOMigration'

function Write-Step {
    param([string]$Message)
    Write-Host "[GPOMigration Build] $Message"
}

function Get-PublicFunctionNames {
    $publicPath = Join-Path $script:ProjectRoot 'src/public'
    $names = [System.Collections.Generic.List[string]]::new()

    Get-ChildItem -Path $publicPath -Filter '*.ps1' -File |
        Where-Object { $_.Name -ne 'README.md' } |
        Sort-Object -Property Name |
        ForEach-Object {
            $tokens = $null
            $errors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors)
            if ($errors.Count -gt 0) {
                throw "Unable to parse public function file '$($_.FullName)'."
            }

            $functions = $ast.FindAll(
                { param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] },
                $false
            )
            foreach ($function in $functions) {
                $names.Add($function.Name)
            }
        }

    if ($names.Count -eq 0) {
        throw 'No public functions were found under src/public.'
    }

    return @($names | Sort-Object -Unique)
}

function Sync-ModuleManifest {
    param(
        [version]$Version,
        [string]$Notes
    )

    $functions = Get-PublicFunctionNames
    $manifestArgs = @{
        Path = $script:ManifestPath
        FunctionsToExport = $functions
    }

    if ($null -ne $Version) {
        $manifestArgs.ModuleVersion = $Version
    }

    if (-not [string]::IsNullOrWhiteSpace($Notes)) {
        $manifestArgs.ReleaseNotes = $Notes
    }

    Update-ModuleManifest @manifestArgs
    Write-Step "Manifest synchronized with $($functions.Count) exported function(s)."
}

function Invoke-PesterByTag {
    param([string]$Tag)

    $testsPath = Join-Path $script:ProjectRoot 'tests'
    $result = Invoke-Pester -Path $testsPath -Tag $Tag -PassThru
    if ($result.FailedCount -gt 0) {
        throw "Pester '$Tag' tests failed: $($result.FailedCount)."
    }
}

function Invoke-RequestedTests {
    if ($TestMetaOnly) {
        Write-Step 'Running meta tests.'
        Invoke-PesterByTag -Tag 'MetaTest'
        return
    }

    if ($TestUnitOnly) {
        Write-Step 'Running unit tests.'
        Invoke-PesterByTag -Tag 'UnitTest'
        return
    }

    if ($TestIntergrationOnly) {
        Write-Step 'Running integration tests.'
        Invoke-PesterByTag -Tag 'IntegrationTest'
        return
    }

    if ($Test) {
        Write-Step 'Running meta and unit tests.'
        Invoke-PesterByTag -Tag 'MetaTest'
        Invoke-PesterByTag -Tag 'UnitTest'
    }
}

function Remove-PathIfExists {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
}

function Copy-Tree {
    param(
        [string]$Source,
        [string]$Destination
    )

    New-Item -Path $Destination -ItemType Directory -Force | Out-Null
    Copy-Item -Path (Join-Path $Source '*') -Destination $Destination -Recurse -Force
}

function Build-ReleaseLayout {
    param([version]$Version)

    $versionText = $Version.ToString()
    $releasePath = Join-Path $script:ReleaseModuleRoot $versionText

    Write-Step "Building release layout for version $versionText."
    New-Item -Path $script:ReleaseModuleRoot -ItemType Directory -Force | Out-Null
    Remove-PathIfExists -Path $releasePath
    New-Item -Path $releasePath -ItemType Directory -Force | Out-Null

    Copy-Tree -Source (Join-Path $script:ProjectRoot 'plugins/OfficeIMO') -Destination (Join-Path $releasePath 'Plugins/OfficeIMO')
    Copy-Tree -Source (Join-Path $script:ProjectRoot 'plugins/sdm-gpmc') -Destination (Join-Path $releasePath 'Plugins/sdm-gpmc')

    Copy-Tree -Source (Join-Path $script:ProjectRoot 'src/other') -Destination (Join-Path $releasePath 'src/other')
    Copy-Tree -Source (Join-Path $script:ProjectRoot 'src/private') -Destination (Join-Path $releasePath 'src/private')

    $publicDestination = Join-Path $releasePath 'src/public'
    New-Item -Path $publicDestination -ItemType Directory -Force | Out-Null
    Get-ChildItem -Path (Join-Path $script:ProjectRoot 'src/public') -File |
        Where-Object { $_.Name -ne 'README.md' } |
        ForEach-Object {
            Copy-Item -Path $_.FullName -Destination (Join-Path $publicDestination $_.Name) -Force
        }

    Copy-Item -Path (Join-Path $script:ProjectRoot 'GPOMigration.psd1') -Destination (Join-Path $releasePath 'GPOMigration.psd1') -Force
    Copy-Item -Path (Join-Path $script:ProjectRoot 'GPOMigration.psm1') -Destination (Join-Path $releasePath 'GPOMigration.psm1') -Force
    Copy-Item -Path (Join-Path $script:ProjectRoot 'LICENSE.md') -Destination (Join-Path $releasePath 'LICENSE.md') -Force
    Copy-Item -Path (Join-Path $script:ProjectRoot 'README.md') -Destination (Join-Path $releasePath 'README.md') -Force

    return $releasePath
}

function New-ReleaseZip {
    param(
        [version]$Version,
        [string]$ReleasePath
    )

    $versionText = $Version.ToString()
    $zipPath = Join-Path $script:ReleaseModuleRoot "GPOMigration-$versionText.zip"
    Remove-PathIfExists -Path $zipPath

    Write-Step "Creating zip package at '$zipPath'."
    Compress-Archive -Path $ReleasePath -DestinationPath $zipPath -CompressionLevel Optimal
    return $zipPath
}

function New-PSGalleryNupkg {
    param(
        [string]$ReleasePath,
        [version]$Version
    )

    $publishModuleCommand = Get-Command -Name Publish-Module -ErrorAction SilentlyContinue
    if ($null -eq $publishModuleCommand) {
        throw 'Publish-Module is required to create a PSGallery-compatible package. Install PowerShellGet and retry.'
    }

    $packagesPath = Join-Path $script:ReleaseModuleRoot 'packages'
    New-Item -Path $packagesPath -ItemType Directory -Force | Out-Null

    $repoName = 'GPOMigrationLocalRepo'
    $existingRepo = Get-PSRepository -Name $repoName -ErrorAction SilentlyContinue
    if ($null -ne $existingRepo) {
        Unregister-PSRepository -Name $repoName
    }

    Register-PSRepository -Name $repoName -SourceLocation $packagesPath -PublishLocation $packagesPath -InstallationPolicy Trusted
    try {
        Write-Step 'Creating PSGallery nupkg package in local repository.'
        Publish-Module -Path $ReleasePath -Repository $repoName -NuGetApiKey 'local' -Force
    }
    finally {
        Unregister-PSRepository -Name $repoName -ErrorAction SilentlyContinue
    }

    $moduleName = 'GPOMigration'
    $versionText = $Version.ToString()
    $nupkgPath = Join-Path $packagesPath "$moduleName.$versionText.nupkg"
    if (-not (Test-Path -LiteralPath $nupkgPath)) {
        throw "NuGet package was not created at expected location '$nupkgPath'."
    }

    return $nupkgPath
}

function Publish-ToPSGallery {
    param(
        [string]$ReleasePath,
        [version]$Version
    )

    $apiKeyToUse = $PSGalleryApiKey
    if ([string]::IsNullOrWhiteSpace($apiKeyToUse)) {
        $apiKeyToUse = $env:PSGALLERY_API_KEY
    }

    if ([string]::IsNullOrWhiteSpace($apiKeyToUse)) {
        throw 'PSGallery API key was not provided. Use -PSGalleryApiKey or set PSGALLERY_API_KEY.'
    }

    Write-Step "Publishing GPOMigration $($Version.ToString()) to PSGallery."
    Publish-Module -Path $ReleasePath -Repository PSGallery -NuGetApiKey $apiKeyToUse -Force
}

function Install-BuiltModule {
    param(
        [string]$ReleasePath,
        [version]$Version
    )

    $moduleInstallRoot = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell/Modules/GPOMigration'
    Remove-PathIfExists -Path $moduleInstallRoot
    New-Item -Path $moduleInstallRoot -ItemType Directory -Force | Out-Null
    Copy-Item -Path (Join-Path $ReleasePath '*') -Destination $moduleInstallRoot -Recurse -Force

    Write-Step 'Validating module import from installed location.'
    Import-Module (Join-Path $moduleInstallRoot 'GPOMigration.psd1') -MinimumVersion $Version -Force
}

function Invoke-BuildRelease {
    param([switch]$InstallModule)

    try {
        $manifest = Test-ModuleManifest -Path $script:ManifestPath
        $moduleVersion = $manifest.Version
    }
    catch {
        Write-Warning "Build.ps1: Test-ModuleManifest validation was skipped: $($_.Exception.Message)"
        $manifestData = Import-PowerShellDataFile -Path $script:ManifestPath
        $moduleVersion = [version]$manifestData.ModuleVersion
    }

    $releasePath = Build-ReleaseLayout -Version $moduleVersion
    $zipPath = New-ReleaseZip -Version $moduleVersion -ReleasePath $releasePath
    Write-Step "Zip package created: $zipPath"

    if ($CreatePSGalleryPackage -or $UploadPSGallery) {
        $nupkgPath = New-PSGalleryNupkg -ReleasePath $releasePath -Version $moduleVersion
        Write-Step "NuGet package created: $nupkgPath"
    }

    if ($UploadPSGallery) {
        Publish-ToPSGallery -ReleasePath $releasePath -Version $moduleVersion
    }

    if ($InstallModule) {
        Install-BuiltModule -ReleasePath $releasePath -Version $moduleVersion
    }
}

if ($AddMissingCBH) {
    Write-Warning 'AddMissingCBH is no longer automated in this build pipeline. Update comment-based help manually as needed.'
    return
}

if ($UpdateRelease) {
    Sync-ModuleManifest -Version $NewVersion -Notes $ReleaseNotes
}

if ($Test -or $TestMetaOnly -or $TestUnitOnly -or $TestIntergrationOnly) {
    Invoke-RequestedTests
}

if ($TestBuildAndInstallModule) {
    Invoke-RequestedTests
    Invoke-BuildRelease -InstallModule
    return
}

if ($BuildModule -or $UploadPSGallery -or $CreatePSGalleryPackage -or ($PSBoundParameters.Count -eq 0)) {
    try {
        Sync-ModuleManifest
    }
    catch {
        if ($UpdateRelease) {
            throw
        }

        Write-Warning "Build.ps1: manifest synchronization was skipped: $($_.Exception.Message)"
    }
    Invoke-BuildRelease
}

