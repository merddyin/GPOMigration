function New-GPOMigrationTemplate {
    <#
    .SYNOPSIS
        Creates a blank GPO migration template file with correct column headers and
        optional example rows.
    .DESCRIPTION
        Generates a CSV or Excel file with the standard GPOMigration export schema
        column headers. Optionally includes one example Administrative Template row
        and one example Group Policy Preference (Drive Maps) row to illustrate the
        expected format.

        This file can be hand-edited to define GPO settings that should be deployed
        to new or updated GPOs via Import-GPOSetting.
    .PARAMETER OutputPath
        Full path to the template file to create.
    .PARAMETER OutputFormat
        'CSV' (default) or 'Excel'.
    .PARAMETER IncludeExamples
        If specified, the template includes two example rows: one Admin Template
        setting and one Drive Maps preference setting.
    .EXAMPLE
        New-GPOMigrationTemplate -OutputPath C:\Templates\MyTemplate.csv

        Creates a blank CSV template with headers.
    .EXAMPLE
        New-GPOMigrationTemplate -OutputPath C:\Templates\MyTemplate.xlsx -OutputFormat Excel -IncludeExamples

        Creates an Excel template with headers and two example rows.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter()]
        [ValidateSet('CSV', 'Excel')]
        [string]$OutputFormat = 'CSV',

        [Parameter()]
        [switch]$IncludeExamples
    )

    begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

        $columnHeaders = @(
            'GPOName', 'GPOGuid', 'Domain', 'Scope', 'Category',
            'PolicyPath', 'SettingName', 'Value', 'ValueType',
            'RegistryKey', 'RegistryValueName', 'State'
        )
    }

    process {
        if (-not $PSCmdlet.ShouldProcess($OutputPath, 'Create GPO migration template')) { return }

        $templateRows = [System.Collections.Generic.List[PSCustomObject]]::new()

        if ($IncludeExamples) {
            # Example 1: Administrative Template registry setting
            $templateRows.Add([PSCustomObject]@{
                GPOName            = 'Example GPO'
                GPOGuid            = '00000000-0000-0000-0000-000000000000'
                Domain             = $env:USERDNSDOMAIN
                Scope              = 'Computer'
                Category           = 'Administrative Templates'
                PolicyPath         = 'Windows Components\BitLocker Drive Encryption'
                SettingName        = 'Allow access to BitLocker-protected fixed drives from earlier versions of Windows'
                Value              = '1'
                ValueType          = 'REG_DWORD'
                RegistryKey        = 'HKLM\SOFTWARE\Policies\Microsoft\FVE'
                RegistryValueName  = 'AllowOldOsEncrypt'
                State              = 'Enabled'
            })

            # Example 2: Group Policy Preference (Drive Maps)
            $templateRows.Add([PSCustomObject]@{
                GPOName            = 'Example GPO'
                GPOGuid            = '00000000-0000-0000-0000-000000000000'
                Domain             = $env:USERDNSDOMAIN
                Scope              = 'User'
                Category           = 'Drive Maps'
                PolicyPath         = ''
                SettingName        = 'H:'
                Value              = '\\server\share'
                ValueType          = ''
                RegistryKey        = ''
                RegistryValueName  = ''
                State              = ''
            })
        }

        # Ensure output directory exists
        $outputDir = Split-Path -Parent $OutputPath
        if ($outputDir -and -not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }

        if ($OutputFormat -eq 'CSV') {
            if ($templateRows.Count -eq 0) {
                # Just headers — write directly
                $headerLine = $columnHeaders -join ','
                [System.IO.File]::WriteAllText($OutputPath, "$headerLine`r`n", [System.Text.Encoding]::UTF8)
            } else {
                $templateRows | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding UTF8
            }
        } else {
            # Excel format
            if ($templateRows.Count -eq 0) {
                # Create empty Excel with just headers
                $excelDoc = [OfficeIMO.Excel.ExcelDocument]::Create($OutputPath)
                $sheet = $excelDoc.Worksheets.Add('Sheet1')
                for ($c = 0; $c -lt $columnHeaders.Count; $c++) {
                    $cell = $sheet.Cells[1, $c + 1]
                    $cell.Value = $columnHeaders[$c]
                    $cell.Style.Font.Bold = $true
                }
                $excelDoc.Save()
                $excelDoc.Dispose()
            } else {
                Format-GPOExcelWorkbook -Rows $templateRows.ToArray() -OutputPath $OutputPath
            }
        }

        Write-Verbose "New-GPOMigrationTemplate: template created at '$OutputPath'."
    }
}
