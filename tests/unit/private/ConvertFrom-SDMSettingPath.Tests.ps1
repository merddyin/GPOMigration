Set-StrictMode -Version Latest

Describe 'ConvertFrom-SDMSettingPath' -Tag 'UnitTest' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\..\..\src\other\PreLoad.ps1')
        . (Join-Path $PSScriptRoot '..\..\..\src\private\Get-CallerPreference.ps1')
        . (Join-Path $PSScriptRoot '..\..\..\src\private\ConvertFrom-SDMSettingPath.ps1')
    }

    It 'parses administrative template path into structured output' {
        $script:AllSupportedAreas = @('Administrative Templates', 'Drive Maps', 'Registry')

        $result = ConvertFrom-SDMSettingPath `
            -SettingPath 'Computer Configuration|Administrative Templates|Windows Components|BitLocker|Policy A' `
            -SettingValue '1' `
            -GPOName 'GPO1' `
            -GPOGuid '{11111111-1111-1111-1111-111111111111}' `
            -Domain 'contoso.com'

        $result.Scope | Should -Be 'Computer'
        $result.Category | Should -Be 'Administrative Templates'
        $result.PolicyPath | Should -Be 'Windows Components\BitLocker'
        $result.SettingName | Should -Be 'Policy A'
    }

    It 'parses preferences category from preferences path' {
        $result = ConvertFrom-SDMSettingPath `
            -SettingPath 'User Configuration|Preferences|Windows Settings|Drive Maps|Map H' `
            -SettingValue '\\server\share' `
            -GPOName 'GPO1' `
            -GPOGuid '{11111111-1111-1111-1111-111111111111}' `
            -Domain 'contoso.com'

        $result.Scope | Should -Be 'User'
        $result.Category | Should -Be 'Drive Maps'
        $result.SettingName | Should -Be 'Map H'
    }

    It 'returns nothing for unsupported category' {
        $script:AllSupportedAreas = @('Registry')

        $result = ConvertFrom-SDMSettingPath `
            -SettingPath 'User Configuration|Preferences|Windows Settings|Drive Maps|Map H' `
            -SettingValue '\\server\share' `
            -GPOName 'GPO1' `
            -GPOGuid '{11111111-1111-1111-1111-111111111111}' `
            -Domain 'contoso.com'

        $null -eq $result | Should -BeTrue
    }
}
