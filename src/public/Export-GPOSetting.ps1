function Export-GPOSetting {
    <#
    .SYNOPSIS
        Exports Group Policy Object settings to CSV or Excel files.
    .DESCRIPTION
        For each specified GPO, calls Out-SDMGPSettings to enumerate all Administrative
        Template and Preference settings, then writes them to CSV (one file per GPO) or
        to a single Excel workbook (one worksheet per GPO plus a TOC sheet).

        Use -IncludeRegistryMapping to populate the RegistryKey, RegistryValueName, and
        ValueType columns for Administrative Template settings by parsing Get-GPOReport XML.
        These columns are required for Import-GPOSetting to re-apply Admin Template rows.
    .PARAMETER DisplayName
        One or more GPO display names. Accepts pipeline input.
    .PARAMETER Id
        One or more GPO GUIDs.
    .PARAMETER Domain
        DNS domain to query. Defaults to the current computer's domain.
    .PARAMETER OutputPath
        Directory where CSV files or the Excel workbook will be written.
        Created if it does not exist.
    .PARAMETER OutputFormat
        'CSV' (default) — one .csv file per GPO.
        'Excel' — a single .xlsx workbook with one sheet per GPO and a TOC sheet.
    .PARAMETER IncludeRegistryMapping
        When specified, calls Get-GPOReport for each GPO to resolve the RegistryKey,
        RegistryValueName, and ValueType columns for Administrative Template rows.
        This makes the exported file suitable for direct Import-GPOSetting use.
    .EXAMPLE
        Export-GPOSetting -DisplayName 'Default Domain Policy' -OutputPath C:\Export

        Exports Admin Template and Preference settings from the named GPO to CSV.
    .EXAMPLE
        Get-GPO -All | Export-GPOSetting -OutputPath C:\Export -OutputFormat Excel -IncludeRegistryMapping

        Exports all GPOs in the domain to a single Excel workbook with registry mappings resolved.
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ByName')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByName', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Name')]
        [string[]]$DisplayName,

        [Parameter(Mandatory, ParameterSetName = 'ById', ValueFromPipelineByPropertyName)]
        [string[]]$Id,

        [Parameter()]
        [string]$Domain = $env:USERDNSDOMAIN,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter()]
        [ValidateSet('CSV', 'Excel')]
        [string]$OutputFormat = 'CSV',

        [Parameter()]
        [switch]$IncludeRegistryMapping
    )

    begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        Test-ModuleDependency | Out-Null

        if (-not (Test-Path $OutputPath)) {
            New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
            Write-Verbose "Export-GPOSetting: created output directory '$OutputPath'."
        }

        $allRows = [System.Collections.Generic.List[PSCustomObject]]::new()
    }

    process {
        # Resolve GPO names from either parameter set
        $gpoNames = @()
        if ($PSCmdlet.ParameterSetName -eq 'ById') {
            foreach ($guid in $Id) {
                try {
                    $gpo = Get-GPO -Guid $guid -Domain $Domain -ErrorAction Stop
                    $gpoNames += $gpo.DisplayName
                } catch {
                    Write-Warning "Export-GPOSetting: could not resolve GPO GUID '$guid': $_"
                }
            }
        } else {
            $gpoNames = $DisplayName
        }

        foreach ($name in $gpoNames) {
            if (-not $PSCmdlet.ShouldProcess($name, 'Export GPO settings')) { continue }

            Write-Verbose "Export-GPOSetting: querying '$name' in '$Domain'."

            # Resolve GUID for registry mapping and output filename
            $gpoGuid = ''
            try {
                $gpoObj  = Get-GPO -Name $name -Domain $Domain -ErrorAction Stop
                $gpoGuid = $gpoObj.Id.ToString('B').ToUpper()
            } catch {
                Write-Warning "Export-GPOSetting: could not retrieve GPO metadata for '$name': $_"
            }

            # Query all supported areas via SDM-GPMC
            $sdmRows = @()
            try {
                $sdmRows = Out-SDMGPSettings -DisplayName $name -Domain $Domain -Areas $script:AllSupportedAreas -ErrorAction Stop
            } catch {
                Write-Warning "Export-GPOSetting: Out-SDMGPSettings failed for '$name': $_"
                continue
            }

            Write-Verbose "Export-GPOSetting: '$name' returned $($sdmRows.Count) raw SDM row(s)."

            $parsedRows = [System.Collections.Generic.List[PSCustomObject]]::new()
            foreach ($sdmRow in $sdmRows) {
                $parsed = ConvertFrom-SDMSettingPath `
                    -SettingPath $sdmRow.SettingPath `
                    -SettingValue $sdmRow.SettingValue `
                    -GPOName $name `
                    -GPOGuid $gpoGuid `
                    -Domain $Domain
                if ($null -ne $parsed) {
                    $parsedRows.Add($parsed)
                }
            }

            Write-Verbose "Export-GPOSetting: '$name' parsed to $($parsedRows.Count) in-scope row(s)."

            # Optionally enrich Admin Template rows with registry mapping
            if ($IncludeRegistryMapping) {
                $adminRows = $parsedRows | Where-Object { $_.Category -in $script:AdminTemplateAreas -or $_.Category -eq 'Extra Registry Settings' }
                foreach ($row in $adminRows) {
                    $mapping = Resolve-RegistryMapping `
                        -GPOName    $name `
                        -GPOGuid    $gpoGuid `
                        -Domain     $Domain `
                        -Scope      $row.Scope `
                        -SettingName $row.SettingName `
                        -PolicyPath  $row.PolicyPath
                    if ($mapping) {
                        $row.RegistryKey       = $mapping.RegistryKey
                        $row.RegistryValueName = $mapping.RegistryValueName
                        $row.ValueType         = $mapping.ValueType
                    }
                }
            }

            foreach ($row in $parsedRows) { $allRows.Add($row) }

            if ($OutputFormat -eq 'CSV') {
                $safeName = $name -replace '[\\\/\*\?\<\>\|:"†]', '_'
                $csvPath  = Join-Path $OutputPath "$safeName.csv"
                $parsedRows | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8 -Force
                Write-Verbose "Export-GPOSetting: wrote CSV to '$csvPath'."
            }
        }
    }

    end {
        if ($OutputFormat -eq 'Excel' -and $allRows.Count -gt 0) {
            $xlsxPath = Join-Path $OutputPath 'GPOSettings.xlsx'
            Format-GPOExcelWorkbook -Rows $allRows.ToArray() -OutputPath $xlsxPath
            Write-Verbose "Export-GPOSetting: wrote Excel workbook to '$xlsxPath'."
        }
        Write-Verbose "Export-GPOSetting: complete. $($allRows.Count) total row(s) exported."
    }
}
