function Format-GPOExcelWorkbook {
    <#
    .SYNOPSIS
        Creates an OfficeIMO.Excel workbook from GPO setting rows and saves it to disk.
    .DESCRIPTION
        Organises rows by GPOName. Creates one worksheet per GPO with an Excel table
        containing all setting columns. Adds a TOC worksheet as the first sheet listing
        each GPO name with a hyperlink to its sheet.

        Requires OfficeIMO.Excel to be loaded (plugins/OfficeIMO/Load.ps1 must have run).
        Throws a terminating error if the assembly is not available.
    .PARAMETER Rows
        Collection of PSCustomObjects with the standard 12-column GPO setting schema.
    .PARAMETER OutputPath
        Full path to the .xlsx file to create (or overwrite).
    .EXAMPLE
        Format-GPOExcelWorkbook -Rows $exportedRows -OutputPath C:\export\GPOSettings.xlsx
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Rows,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

        if (-not $script:OfficeIMOLoaded) {
            throw "Format-GPOExcelWorkbook: OfficeIMO.Excel is not loaded. Ensure the OfficeIMO plugin DLLs are present in plugins/OfficeIMO/lib/."
        }

        $columnHeaders = @(
            'GPOName', 'GPOGuid', 'Domain', 'Scope', 'Category',
            'PolicyPath', 'SettingName', 'Value', 'ValueType',
            'RegistryKey', 'RegistryValueName', 'State'
        )

        # Scope validation list for data validation dropdown
        $scopeList     = @('Computer', 'User')
        $valueTypeList = @('REG_SZ', 'REG_DWORD', 'REG_QWORD', 'REG_EXPAND_SZ', 'REG_MULTI_SZ', 'REG_BINARY')
    }

    process {
        Write-Verbose "Format-GPOExcelWorkbook: creating workbook at '$OutputPath'."

        # Ensure output directory exists
        $outputDir = Split-Path -Parent $OutputPath
        if ($outputDir -and -not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }

        $excel = [OfficeIMO.Excel.ExcelDocument]::Create($OutputPath)
        try {
            # ---- TOC sheet ----
            $tocSheet = $excel.Worksheets.Add('TOC')
            $tocSheet.Cells['A1'].Value = 'GPO Name'
            $tocSheet.Cells['B1'].Value = 'Sheet'
            $tocSheet.Cells['A1'].Style.Font.Bold = $true
            $tocSheet.Cells['B1'].Style.Font.Bold = $true

            $gpoGroups = $Rows | Group-Object -Property GPOName
            $tocRow = 2

            foreach ($group in $gpoGroups) {
                $gpoName  = $group.Name
                # Sanitise sheet name: Excel sheet names max 31 chars, no special chars
                $sheetName = ($gpoName -replace '[\\\/\*\?\[\]:]', '_').Substring(0, [Math]::Min($gpoName.Length, 31))
                $gpoSheet  = $excel.Worksheets.Add($sheetName)

                # Write column headers
                for ($c = 0; $c -lt $columnHeaders.Count; $c++) {
                    $cell = $gpoSheet.Cells[1, $c + 1]
                    $cell.Value = $columnHeaders[$c]
                    $cell.Style.Font.Bold = $true
                    $cell.Style.Fill.PatternType = [OfficeIMO.Excel.ExcelFillStyle]::Solid
                    $cell.Style.Fill.BackgroundColor.SetColor([System.Drawing.Color]::FromArgb(68, 114, 196))
                    $cell.Style.Font.Color.SetColor([System.Drawing.Color]::White)
                }

                # Write data rows
                $dataRows = $group.Group
                for ($r = 0; $r -lt $dataRows.Count; $r++) {
                    $row = $dataRows[$r]
                    $excelRow = $r + 2
                    $gpoSheet.Cells[$excelRow, 1].Value  = $row.GPOName
                    $gpoSheet.Cells[$excelRow, 2].Value  = $row.GPOGuid
                    $gpoSheet.Cells[$excelRow, 3].Value  = $row.Domain
                    $gpoSheet.Cells[$excelRow, 4].Value  = $row.Scope
                    $gpoSheet.Cells[$excelRow, 5].Value  = $row.Category
                    $gpoSheet.Cells[$excelRow, 6].Value  = $row.PolicyPath
                    $gpoSheet.Cells[$excelRow, 7].Value  = $row.SettingName
                    $gpoSheet.Cells[$excelRow, 8].Value  = $row.Value
                    $gpoSheet.Cells[$excelRow, 9].Value  = $row.ValueType
                    $gpoSheet.Cells[$excelRow, 10].Value = $row.RegistryKey
                    $gpoSheet.Cells[$excelRow, 11].Value = $row.RegistryValueName
                    $gpoSheet.Cells[$excelRow, 12].Value = $row.State
                }

                # Freeze top row and auto-fit columns
                $gpoSheet.View.FreezePanes(2, 1)
                $gpoSheet.Cells[$gpoSheet.Dimension.Address].AutoFitColumns()

                # Populate TOC row
                $tocSheet.Cells[$tocRow, 1].Value = $gpoName
                $tocSheet.Cells[$tocRow, 2].Hyperlink = New-Object OfficeIMO.Excel.ExcelHyperLink("#'$sheetName'!A1", $sheetName)
                $tocRow++
            }

            $tocSheet.Cells[$tocSheet.Dimension.Address].AutoFitColumns()
            $excel.Save()
            Write-Verbose "Format-GPOExcelWorkbook: workbook saved to '$OutputPath'."
        } finally {
            $excel.Dispose()
        }
    }
}
