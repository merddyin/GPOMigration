Set-StrictMode -Version Latest

Describe 'New-GPOMigrationTemplate' -Tag 'UnitTest' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\..\..\src\private\Get-CallerPreference.ps1')
        . (Join-Path $PSScriptRoot '..\..\..\src\public\New-GPOMigrationTemplate.ps1')

        function Format-GPOExcelWorkbook { }
    }

    It 'creates a CSV template with headers when examples are not requested' {
        $path = Join-Path $TestDrive 'template.csv'

        New-GPOMigrationTemplate -OutputPath $path -OutputFormat CSV -Confirm:$false

        Test-Path -LiteralPath $path | Should -BeTrue
        $content = Get-Content -LiteralPath $path -Raw
        $content | Should -Match 'GPOName'
        $content | Should -Match 'RegistryValueName'
    }

    It 'creates CSV with data rows when examples are requested' {
        $path = Join-Path $TestDrive 'template-with-examples.csv'

        New-GPOMigrationTemplate -OutputPath $path -OutputFormat CSV -IncludeExamples -Confirm:$false

        $lines = Get-Content -LiteralPath $path
        $lines.Count | Should -BeGreaterThan 1
    }

    It 'routes Excel with examples to Format-GPOExcelWorkbook' {
        Mock -CommandName Format-GPOExcelWorkbook

        New-GPOMigrationTemplate -OutputPath (Join-Path $TestDrive 'template.xlsx') -OutputFormat Excel -IncludeExamples -Confirm:$false

        Should -Invoke Format-GPOExcelWorkbook -Times 1
    }
}
