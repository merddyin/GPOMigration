function Import-RegistryPolicySetting {
    <#
    .SYNOPSIS
        Applies a single Administrative Template (registry-backed) setting to a GPO.
    .DESCRIPTION
        Calls Set-GPRegistryValue to write one setting row from the CSV/Excel schema
        into the target GPO. Converts the ValueType string from the schema
        (e.g. 'REG_DWORD') to [Microsoft.Win32.RegistryValueKind] using the module-scoped
        $script:RegistryTypeMap table.

        The Value column is cast appropriately for the target type:
          - DWORD / QWORD: parsed to [int32] / [int64]
          - BINARY: decoded from a comma-separated byte list or hex string
          - MULTI_SZ: decoded from a pipe-separated string
          - All others: passed as-is (string)
    .PARAMETER Row
        One PSCustomObject with the standard 12-column GPO setting schema.
    .PARAMETER GPOName
        Target GPO display name. If provided, overrides Row.GPOName.
    .PARAMETER Domain
        DNS domain of the GPO. If provided, overrides Row.Domain.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Row,

        [Parameter()]
        [string]$GPOName,

        [Parameter()]
        [string]$Domain
    )

    begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
    }

    process {
        $targetGPO    = if ($PSBoundParameters.ContainsKey('GPOName') -and $GPOName) { $GPOName } else { $Row.GPOName }
        $targetDomain = if ($PSBoundParameters.ContainsKey('Domain') -and $Domain) { $Domain } else { $Row.Domain }

        if (-not $Row.RegistryKey) {
            Write-Warning "Import-RegistryPolicySetting: RegistryKey is empty for '$($Row.SettingName)' in '$targetGPO'. Row skipped — re-export with -IncludeRegistryMapping to populate this field."
            return
        }

        # Resolve value kind
        $typeKey = $Row.ValueType.ToUpper().Trim()
        if (-not $script:RegistryTypeMap.ContainsKey($typeKey)) {
            Write-Warning "Import-RegistryPolicySetting: unknown ValueType '$($Row.ValueType)' for '$($Row.SettingName)'; defaulting to REG_SZ."
            $typeKey = 'REG_SZ'
        }
        $valueKind = $script:RegistryTypeMap[$typeKey]

        # Cast the value to the correct .NET type
        $typedValue = switch ($typeKey) {
            'REG_DWORD'    { [int32]$Row.Value }
            'REG_QWORD'    { [int64]$Row.Value }
            'REG_BINARY'   {
                # Accept comma-separated decimal bytes OR space-separated hex bytes
                $parts = $Row.Value -split '[,\s]' | Where-Object { $_ -ne '' }
                [byte[]]($parts | ForEach-Object {
                    $part = $_.Trim()
                    $base = if ($part.Length -le 2 -and $part -notmatch '^\d+$') { 16 } else { 10 }
                    [Convert]::ToByte($part, $base)
                })
            }
            'REG_MULTI_SZ' {
                # Stored as pipe-separated values in the CSV
                [string[]]($Row.Value -split '\|')
            }
            default { [string]$Row.Value }
        }

        $gpoScope = if ($Row.Scope -eq 'User') { 'User' } else { 'Computer' }

        Write-Verbose "Import-RegistryPolicySetting: $gpoScope\$($Row.RegistryKey)\$($Row.RegistryValueName) [$typeKey] = $($Row.Value)"

        $splat = @{
            Name        = $targetGPO
            Domain      = $targetDomain
            Key         = $Row.RegistryKey
            ValueName   = $Row.RegistryValueName
            Type        = $valueKind
            Value       = $typedValue
            ErrorAction = 'Stop'
        }
        if ($gpoScope -eq 'User') {
            $splat['Server'] = $targetDomain
            Set-GPRegistryValue @splat -User
        } else {
            Set-GPRegistryValue @splat
        }
    }
}
