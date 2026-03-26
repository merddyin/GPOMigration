function ConvertFrom-SDMSettingPath {
    <#
    .SYNOPSIS
        Parses a pipe-delimited SDM SettingPath string into structured fields.
    .DESCRIPTION
        Out-SDMGPSettings returns a SettingPath in the form:
          <ScopeLabel>|<ConfigArea>|[SubPath segments...]|<SettingName>

        Examples:
          "Computer Configuration|Administrative Templates|Windows Components|BitLocker Drive Encryption|Allow access..."
          "User Configuration|Preferences|Windows Settings|Drive Maps|Map H: to \\server\share"

        This function decomposes that into Scope, Category, PolicyPath, and SettingName.
        Rows whose Category is not in $script:AllSupportedAreas are filtered and not returned.
    .PARAMETER SettingPath
        The pipe-delimited SDM SettingPath string.
    .PARAMETER SettingValue
        The raw setting value from Out-SDMGPSettings. Passed through to the output object.
    .PARAMETER GPOName
        The GPO display name. Passed through to the output object.
    .PARAMETER GPOGuid
        The GPO GUID. Passed through to the output object.
    .PARAMETER Domain
        The DNS domain of the GPO. Passed through to the output object.
    .OUTPUTS
        [PSCustomObject] with GPOName, GPOGuid, Domain, Scope, Category,
        PolicyPath, SettingName, Value. Returns nothing for out-of-scope paths.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$SettingPath,

        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$SettingValue,

        [Parameter(Mandatory)]
        [string]$GPOName,

        [Parameter(Mandatory)]
        [string]$GPOGuid,

        [Parameter(Mandatory)]
        [string]$Domain
    )

    begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
    }

    process {
        $segments = $SettingPath -split '\|'

        if ($segments.Count -lt 3) {
            Write-Verbose "ConvertFrom-SDMSettingPath: skipping short path '$SettingPath'."
            return
        }

        # Determine scope from first segment
        $scopeLabel = $segments[0].Trim()
        $scope = switch -Wildcard ($scopeLabel) {
            'Computer*' { 'Computer' }
            'Machine*'  { 'Computer' }
            'User*'     { 'User' }
            default {
                Write-Verbose "ConvertFrom-SDMSettingPath: unrecognised scope label '$scopeLabel'; skipping."
                return
            }
        }

        # Second segment is the config area (e.g. "Administrative Templates" or "Preferences")
        $configArea = $segments[1].Trim()

        # Determine the Category used in our CSV schema
        $category = switch -Wildcard ($configArea) {
            'Administrative Templates' {
                # Third segment onward forms the PolicyPath; leaf is SettingName
                # Category column value matches the SDM area that produced this row
                'Administrative Templates'
            }
            'Extra Registry Settings' {
                'Extra Registry Settings'
            }
            'Preferences' {
                # Format: Preferences|<WindowsOrControlPanel>Settings|<PreferenceType>|<SettingName>
                # The preference type is typically at index 3
                if ($segments.Count -ge 4) { $segments[3].Trim() } else { $segments[2].Trim() }
            }
            default {
                Write-Verbose "ConvertFrom-SDMSettingPath: unrecognised config area '$configArea'; skipping."
                return
            }
        }

        # Filter out any category not in our supported set
        if ($category -notin $script:AllSupportedAreas) {
            Write-Verbose "ConvertFrom-SDMSettingPath: category '$category' is out of scope; skipping."
            return
        }

        # SettingName is the last segment; PolicyPath is everything between scope+configArea and SettingName
        $settingName = $segments[-1].Trim()

        # PolicyPath: start after configArea (index 2) and stop before the last segment
        if ($configArea -like 'Preferences') {
            # Skip "Windows Settings"/"Control Panel Settings" grouping segment (index 2)
            $pathStart = 4
        } else {
            $pathStart = 2
        }
        $pathSegments = $segments[$pathStart..($segments.Count - 2)] | ForEach-Object { $_.Trim() } |
            Where-Object { $_ -ne '' }
        $policyPath = if ($pathSegments) { $pathSegments -join '\' } else { '' }

        [PSCustomObject]@{
            GPOName     = $GPOName
            GPOGuid     = $GPOGuid
            Domain      = $Domain
            Scope       = $scope
            Category    = $category
            PolicyPath  = $policyPath
            SettingName = $settingName
            Value       = $SettingValue
            ValueType   = ''
            RegistryKey = ''
            RegistryValueName = ''
            State       = ''
        }
    }
}
