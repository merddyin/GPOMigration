Set-StrictMode -Version Latest

Describe 'Format-GPOExcelWorkbook' -Tag 'UnitTest' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\..\..\src\private\Get-CallerPreference.ps1')
        . (Join-Path $PSScriptRoot '..\..\..\src\private\Format-GPOExcelWorkbook.ps1')
    }

    It 'throws when OfficeIMO is not loaded' {
        $script:OfficeIMOLoaded = $false
        $rows = @([pscustomobject]@{ GPOName='GPO1' })

        { Format-GPOExcelWorkbook -Rows $rows -OutputPath (Join-Path $TestDrive 'x.xlsx') } | Should -Throw
    }
}
