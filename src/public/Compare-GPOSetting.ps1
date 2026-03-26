function Compare-GPOSetting {
    <#
    .SYNOPSIS
        Compares two GPO setting export files (CSV or Excel) and shows differences.
    .DESCRIPTION
        Loads two files in the standard GPOMigration export schema and produces a
        detailed diff showing which settings exist only in the reference file,
        only in the difference file, or in both with different values.

        Comparison is performed on the key columns: PolicyPath, SettingName, Value
        (by default), or on columns you specify via -Property.
    .PARAMETER ReferencePath
        Path to the reference (baseline) CSV or XLSX file.
    .PARAMETER DifferencePath
        Path to the difference (target) CSV or XLSX file.
    .PARAMETER Property
        Column names to use as the comparison key and for output.
        Default: GPOName, PolicyPath, SettingName, Value, Category.
    .OUTPUTS
        [PSCustomObject[]] with SideIndicator showing '<=', '=>', or '==':
          '<=' — Row exists in Reference only
          '=>' — Row exists in Difference only
          '==' — Row exists in both with the same key values
    .EXAMPLE
        Compare-GPOSetting -ReferencePath C:\Export\Baseline.csv -DifferencePath C:\Export\Current.csv

        Shows differences between two CSV exports.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [string]$ReferencePath,

        [Parameter(Mandatory)]
        [string]$DifferencePath,

        [Parameter()]
        [string[]]$Property = @('GPOName', 'PolicyPath', 'SettingName', 'Value', 'Category')
    )

    begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
    }

    process {
        Write-Verbose "Compare-GPOSetting: loading reference file '$ReferencePath'."
        $refRows = if ($ReferencePath -like '*.xlsx') {
            Write-Warning "Compare-GPOSetting: Excel file reading is not yet implemented. Please convert to CSV."
            @()
        } else {
            @(Import-Csv -LiteralPath $ReferencePath)
        }

        Write-Verbose "Compare-GPOSetting: loading difference file '$DifferencePath'."
        $diffRows = if ($DifferencePath -like '*.xlsx') {
            Write-Warning "Compare-GPOSetting: Excel file reading is not yet implemented. Please convert to CSV."
            @()
        } else {
            @(Import-Csv -LiteralPath $DifferencePath)
        }

        if ($refRows.Count -eq 0 -or $diffRows.Count -eq 0) {
            Write-Warning "Compare-GPOSetting: one or both files are empty or unreadable."
            return
        }

        # Create a composite key from the Property columns for comparison
        $refKeyed = $refRows | Group-Object -Property $Property -AsHashTable -AsString
        $diffKeyed = $diffRows | Group-Object -Property $Property -AsHashTable -AsString

        $results = [System.Collections.Generic.List[PSCustomObject]]::new()

        # Reference-only rows
        foreach ($key in $refKeyed.Keys) {
            if ($key -notin $diffKeyed.Keys) {
                $results.Add([PSCustomObject]@{
                    PSTypeName     = 'GPOMigration.ComparisonResult'
                    SideIndicator  = '<='
                    GPOName        = $refKeyed[$key][0].GPOName
                    PolicyPath     = $refKeyed[$key][0].PolicyPath
                    SettingName    = $refKeyed[$key][0].SettingName
                    Value          = $refKeyed[$key][0].Value
                    Category       = $refKeyed[$key][0].Category
                    Scope          = $refKeyed[$key][0].Scope
                })
            }
        }

        # Difference-only rows and common rows with same key
        foreach ($key in $diffKeyed.Keys) {
            if ($key -notin $refKeyed.Keys) {
                $results.Add([PSCustomObject]@{
                    PSTypeName     = 'GPOMigration.ComparisonResult'
                    SideIndicator  = '=>'
                    GPOName        = $diffKeyed[$key][0].GPOName
                    PolicyPath     = $diffKeyed[$key][0].PolicyPath
                    SettingName    = $diffKeyed[$key][0].SettingName
                    Value          = $diffKeyed[$key][0].Value
                    Category       = $diffKeyed[$key][0].Category
                    Scope          = $diffKeyed[$key][0].Scope
                })
            } else {
                $results.Add([PSCustomObject]@{
                    PSTypeName     = 'GPOMigration.ComparisonResult'
                    SideIndicator  = '=='
                    GPOName        = $diffKeyed[$key][0].GPOName
                    PolicyPath     = $diffKeyed[$key][0].PolicyPath
                    SettingName    = $diffKeyed[$key][0].SettingName
                    Value          = $diffKeyed[$key][0].Value
                    Category       = $diffKeyed[$key][0].Category
                    Scope          = $diffKeyed[$key][0].Scope
                })
            }
        }

        Write-Verbose "Compare-GPOSetting: found $($results.Count) comparison result(s)."
        $results
    }
}
