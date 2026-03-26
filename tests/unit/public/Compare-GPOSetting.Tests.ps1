Set-StrictMode -Version Latest

Describe 'Compare-GPOSetting' -Tag 'UnitTest' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\..\..\src\private\Get-CallerPreference.ps1')
        . (Join-Path $PSScriptRoot '..\..\..\src\public\Compare-GPOSetting.ps1')
    }

    It 'returns expected side indicators for ref-only, diff-only, and common rows' {
        $refPath = Join-Path $TestDrive 'ref.csv'
        $diffPath = Join-Path $TestDrive 'diff.csv'

        @'
GPOName,PolicyPath,SettingName,Value,Category,Scope
GPO1,PathA,SettingA,1,Administrative Templates,Computer
GPO1,PathB,SettingB,2,Administrative Templates,Computer
'@ | Set-Content -LiteralPath $refPath -Encoding UTF8

        @'
GPOName,PolicyPath,SettingName,Value,Category,Scope
GPO1,PathB,SettingB,2,Administrative Templates,Computer
GPO1,PathC,SettingC,3,Drive Maps,User
'@ | Set-Content -LiteralPath $diffPath -Encoding UTF8

        $result = Compare-GPOSetting -ReferencePath $refPath -DifferencePath $diffPath

        ($result | Where-Object SideIndicator -eq '==').Count | Should -Be 1
        ($result | Where-Object SideIndicator -eq '<=').Count | Should -Be 1
        ($result | Where-Object SideIndicator -eq '=>').Count | Should -Be 1
    }

    It 'returns no results when xlsx input is provided' {
        Mock -CommandName Write-Warning

        $result = Compare-GPOSetting -ReferencePath 'ref.xlsx' -DifferencePath 'diff.xlsx'

        $null -eq $result | Should -BeTrue
        Should -Invoke Write-Warning -Times 3
    }
}
