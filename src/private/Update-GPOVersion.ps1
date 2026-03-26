function Update-GPOVersion {
    <#
    .SYNOPSIS
        Writes a Preferences XML file to SYSVOL and increments the GPO version counter
        in gpt.ini.
    .DESCRIPTION
        Checks whether the current user is a member of Domain Admins (SID suffix -512)
        using WindowsIdentity.GetCurrent().Groups.

        If Domain Admin:
          - Writes XmlContent to the correct SYSVOL Preferences subfolder
          - Reads gpt.ini, increments the appropriate 16-bit half of the Version field,
            and writes the file back
          - Returns an object with WrittenToSYSVOL = $true

        If NOT Domain Admin:
          - Creates a local staging structure under LocalFallbackPath\SYSVOL_Staging\
          - Writes XmlContent there alongside a copy of gpt.ini showing the required version
          - Emits Write-Warning with exact source and target paths
          - Returns an object with WrittenToSYSVOL = $false

        NOTE: This function does not update gPCMachineExtensionNames /
        gPCUserExtensionNames in Active Directory. GPMC normally handles that when
        preferences are configured interactively. Administrators applying the staged
        files should also update those AD attributes if required by their environment.
    .PARAMETER GPOGuid
        GUID of the target GPO, including braces (e.g. '{XXXXXXXX-...}').
    .PARAMETER Domain
        DNS domain of the GPO.
    .PARAMETER Scope
        'Computer' or 'User' — determines the Machine/User subtree in SYSVOL.
    .PARAMETER Category
        Preference category name (must be a key in $script:PreferenceSYSVOLMap).
    .PARAMETER XmlContent
        The Preferences XML string produced by ConvertTo-GPPreferenceXml.
    .PARAMETER LocalFallbackPath
        Directory to use for staging when not running as Domain Admin.
        Defaults to the current working directory.
    .OUTPUTS
        [PSCustomObject] with: Success (bool), WrittenToSYSVOL (bool),
        SysvlPath (string), LocalPath (string), Message (string).
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$GPOGuid,

        [Parameter(Mandatory)]
        [string]$Domain,

        [Parameter(Mandatory)]
        [ValidateSet('Computer', 'User')]
        [string]$Scope,

        [Parameter(Mandatory)]
        [string]$Category,

        [Parameter(Mandatory)]
        [string]$XmlContent,

        [Parameter()]
        [string]$LocalFallbackPath = (Get-Location).Path
    )

    begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
    }

    process {
        # Normalise GUID to {XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX} format
        if ($GPOGuid -notmatch '^\{') { $GPOGuid = "{$GPOGuid}" }

        # Resolve SYSVOL folder and XML filename from category maps
        if (-not $script:PreferenceSYSVOLMap.ContainsKey($Category)) {
            throw "Update-GPOVersion: '$Category' is not in `$script:PreferenceSYSVOLMap."
        }
        $prefFolder  = $script:PreferenceSYSVOLMap[$Category]
        $xmlFileName = $script:PreferenceXmlFileMap[$Category]
        $scopeFolder = if ($Scope -eq 'Computer') { 'Machine' } else { 'User' }

        # SYSVOL canonical path
        $sysvlBase     = "\\$Domain\SYSVOL\$Domain\Policies\$GPOGuid"
        $sysvlPrefDir  = Join-Path $sysvlBase "$scopeFolder\Preferences\$prefFolder"
        $sysvlXmlPath  = Join-Path $sysvlPrefDir $xmlFileName
        $sysvlGptPath  = Join-Path $sysvlBase 'gpt.ini'

        # --- Domain Admin check ---
        $identity  = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $isDomainAdmin = $false
        foreach ($group in $identity.Groups) {
            if ($group.Value -match '-512$') {
                $isDomainAdmin = $true
                break
            }
        }

        if ($isDomainAdmin) {
            # ---- Write directly to SYSVOL ----
            try {
                if (-not (Test-Path $sysvlPrefDir)) {
                    New-Item -ItemType Directory -Path $sysvlPrefDir -Force | Out-Null
                }
                [System.IO.File]::WriteAllText($sysvlXmlPath, $XmlContent, [System.Text.Encoding]::UTF8)
                Write-Verbose "Update-GPOVersion: wrote '$xmlFileName' to '$sysvlPrefDir'."

                # Update gpt.ini version counter
                $newVersion = Update-GptIniVersion -GptIniPath $sysvlGptPath -Scope $Scope
                Write-Verbose "Update-GPOVersion: gpt.ini version now $newVersion."

                return [PSCustomObject]@{
                    Success         = $true
                    WrittenToSYSVOL = $true
                    SysvlPath       = $sysvlXmlPath
                    LocalPath       = ''
                    Message         = "Written to SYSVOL. gpt.ini version: $newVersion."
                }
            } catch {
                throw "Update-GPOVersion: failed to write to SYSVOL path '$sysvlPrefDir': $_"
            }
        } else {
            # ---- Local fallback / staging ----
            $stagingBase   = Join-Path $LocalFallbackPath "SYSVOL_Staging\$GPOGuid"
            $stagingPrefDir = Join-Path $stagingBase "$scopeFolder\Preferences\$prefFolder"
            $stagingXmlPath = Join-Path $stagingPrefDir $xmlFileName
            $stagingGptPath = Join-Path $stagingBase 'gpt.ini'

            if (-not (Test-Path $stagingPrefDir)) {
                New-Item -ItemType Directory -Path $stagingPrefDir -Force | Out-Null
            }
            [System.IO.File]::WriteAllText($stagingXmlPath, $XmlContent, [System.Text.Encoding]::UTF8)

            # Generate a placeholder gpt.ini (administrator must merge version manually)
            $placeholderGpt = "[General]`r`ngPCFunctionalityVersion=2`r`ndisplayName=New Group Policy Object`r`nflags=0`r`nVersion=1`r`n"
            [System.IO.File]::WriteAllText($stagingGptPath, $placeholderGpt, [System.Text.Encoding]::UTF8)

            $msg = "Current user is not a Domain Admin. Preferences XML staged locally.`n  Local source : $stagingXmlPath`n  SYSVOL target: $sysvlXmlPath`nCopy the file to SYSVOL and merge gpt.ini Version with '$stagingGptPath' to activate the settings."
            Write-Warning $msg

            return [PSCustomObject]@{
                Success         = $true
                WrittenToSYSVOL = $false
                SysvlPath       = $sysvlXmlPath
                LocalPath       = $stagingXmlPath
                Message         = $msg
            }
        }
    }
}

# Internal helper — not exported
function Update-GptIniVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$GptIniPath,
        [Parameter(Mandatory)] [ValidateSet('Computer','User')] [string]$Scope
    )

    $content = if (Test-Path $GptIniPath) {
        [System.IO.File]::ReadAllText($GptIniPath)
    } else {
        "[General]`r`ngPCFunctionalityVersion=2`r`ndisplayName=New Group Policy Object`r`nflags=0`r`nVersion=0`r`n"
    }

    if ($content -match 'Version=(\d+)') {
        $currentVersion = [int]$Matches[1]
    } else {
        $currentVersion = 0
    }

    # Version is encoded as (UserVersion << 16) | MachineVersion
    $machineVer = $currentVersion -band 0xFFFF
    $userVer    = ($currentVersion -shr 16) -band 0xFFFF

    if ($Scope -eq 'Computer') { $machineVer++ } else { $userVer++ }

    $newVersion = ($userVer -shl 16) -bor $machineVer

    if ($content -match 'Version=\d+') {
        $content = $content -replace 'Version=\d+', "Version=$newVersion"
    } else {
        $content += "Version=$newVersion`r`n"
    }

    [System.IO.File]::WriteAllText($GptIniPath, $content, [System.Text.Encoding]::UTF8)
    $newVersion
}
