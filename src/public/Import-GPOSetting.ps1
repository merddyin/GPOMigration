function Import-GPOSetting {
    <#
    .SYNOPSIS
        Imports Group Policy Object settings from CSV or Excel files.
    .DESCRIPTION
        Reads settings from one or more CSV or Excel files (in the standard
        GPOMigration export schema) and applies them to target GPOs, either existing
        or newly created.

        Administrative Template rows are applied via Set-GPRegistryValue.
        Preference rows are split: Registry preferences use Set-GPPrefRegistryValue,
        while all other preference types are written as XML to SYSVOL (or a local
        staging directory if not running as Domain Admin).

        Rows without a RegistryKey/ValueType (Admin Templates that lacked mapping
        when exported) will be skipped with a warning. Re-export with -IncludeRegistryMapping
        to obtain those fields.
    .PARAMETER Path
        One or more CSV or XLSX files, or a directory containing CSV/XLSX files.
        Files are auto-discovered by extension.
        Accepts pipeline input.
    .PARAMETER GPOName
        Override the GPOName column in the input file. All rows will be applied
        to this GPO instead.
    .PARAMETER Domain
        DNS domain where the GPOs will be created/modified.
        Defaults to the current domain.
    .PARAMETER CreateIfMissing
        If specified, creates any GPO that does not exist before attempting to
        apply settings to it.
    .PARAMETER LocalFallbackPath
        Staging directory used when the current user is not a Domain Admin.
        Preference XML files that cannot be written to SYSVOL are placed here.
        Defaults to the current working directory.
    .EXAMPLE
        Import-GPOSetting -Path C:\Export\MyGPO.csv -GPOName 'Production Policy'

        Applies all settings from the CSV to the named GPO.
    .EXAMPLE
        Import-GPOSetting -Path C:\Export\GPOSettings.xlsx -CreateIfMissing -WhatIf

        Previews what settings would be imported from an Excel workbook,
        creating GPOs as needed.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String[]]$Path,

        [Parameter()]
        [string]$GPOName,

        [Parameter()]
        [string]$Domain = $env:USERDNSDOMAIN,

        [Parameter()]
        [switch]$CreateIfMissing,

        [Parameter()]
        [string]$LocalFallbackPath = (Get-Location).Path
    )

    begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        Test-ModuleDependency | Out-Null
    }

    process {
        $filePaths = [System.Collections.Generic.List[string]]::new()

        foreach ($inputPath in $Path) {
            if (Test-Path -LiteralPath $inputPath -PathType Leaf) {
                $filePaths.Add($inputPath)
            } elseif (Test-Path -LiteralPath $inputPath -PathType Container) {
                Get-ChildItem -LiteralPath $inputPath -Filter '*.csv' | ForEach-Object { $filePaths.Add($_.FullName) }
                Get-ChildItem -LiteralPath $inputPath -Filter '*.xlsx' | ForEach-Object { $filePaths.Add($_.FullName) }
            } else {
                Write-Warning "Import-GPOSetting: path not found '$inputPath'."
            }
        }

        foreach ($filePath in $filePaths) {
            Write-Verbose "Import-GPOSetting: reading '$filePath'."

            $rows = if ($filePath -like '*.xlsx') {
                # Excel file — would require OfficeIMO to read; for now, emit a warning
                Write-Warning "Import-GPOSetting: Excel file reading is not yet implemented. Please export to CSV or manually convert to CSV."
                @()
            } else {
                Import-Csv -LiteralPath $filePath
            }

            if ($rows.Count -eq 0) {
                Write-Verbose "Import-GPOSetting: '$filePath' is empty or unreadable."
                continue
            }

            # Group by GPOName (from file or parameter)
            $rowGroups = if ($GPOName) {
                @{ $GPOName = $rows }
            } else {
                $rows | Group-Object -Property GPOName -AsHashTable
            }

            foreach ($gpoName in $rowGroups.Keys) {
                if (-not $PSCmdlet.ShouldProcess($gpoName, 'Import GPO settings from file')) { continue }

                Write-Verbose "Import-GPOSetting: preparing to import $($rowGroups[$gpoName].Count) row(s) to '$gpoName'."

                # Ensure GPO exists
                $gpo = Get-GPO -Name $gpoName -Domain $Domain -ErrorAction SilentlyContinue
                if (-not $gpo) {
                    if (-not $CreateIfMissing) {
                        Write-Warning "Import-GPOSetting: GPO '$gpoName' not found in '$Domain'. Use -CreateIfMissing to create it."
                        continue
                    }
                    Write-Verbose "Import-GPOSetting: creating GPO '$gpoName' in '$Domain'."
                    try {
                        $gpo = New-GPO -Name $gpoName -Domain $Domain -ErrorAction Stop
                    } catch {
                        Write-Warning "Import-GPOSetting: failed to create GPO '$gpoName': $_"
                        continue
                    }
                }

                $groupRows = $rowGroups[$gpoName]
                $gpoGuid   = $gpo.Id.ToString('B').ToUpper()

                # Partition rows by category type
                $adminRows = $groupRows | Where-Object { $_.Category -in $script:AdminTemplateAreas -or $_.Category -eq 'Extra Registry Settings' }
                $prefRows  = $groupRows | Where-Object { $_.Category -notin $script:AdminTemplateAreas -and $_.Category -ne 'Extra Registry Settings' }

                # Apply Admin Template settings
                foreach ($row in $adminRows) {
                    if (-not $row.RegistryKey) {
                        Write-Warning "Import-GPOSetting: RegistryKey missing for '$($row.SettingName)' in '$gpoName'; skipping."
                        continue
                    }
                    try {
                        Import-RegistryPolicySetting -Row $row -GPOName $gpoName -Domain $Domain
                    } catch {
                        Write-Warning "Import-GPOSetting: failed to apply registry setting '$($row.SettingName)': $_"
                    }
                }

                # Apply Preference settings
                if ($prefRows) {
                    try {
                        Import-PreferencePolicySetting `
                            -Rows $prefRows `
                            -GPOName $gpoName `
                            -GPOGuid $gpoGuid `
                            -Domain $Domain `
                            -LocalFallbackPath $LocalFallbackPath
                    } catch {
                        Write-Warning "Import-GPOSetting: failed to apply preference settings: $_"
                    }
                }
            }
        }
    }
}
