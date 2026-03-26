Set-StrictMode -Version Latest

Describe 'Import-PreferencePolicySetting' -Tag 'UnitTest' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\..\..\src\other\PreLoad.ps1')
        . (Join-Path $PSScriptRoot '..\..\..\src\private\Get-CallerPreference.ps1')
        . (Join-Path $PSScriptRoot '..\..\..\src\private\Import-PreferencePolicySetting.ps1')

        function ConvertTo-GPPreferenceXml { }
        function Update-GPOVersion { }
        function Set-GPPrefRegistryValue { }
    }

    It 'routes Windows Registry rows to Set-GPPrefRegistryValue and XML rows to XML pipeline' {
        $rows = @(
            [pscustomobject]@{ GPOName='GPO1'; Scope='Computer'; Category='Windows Registry'; RegistryKey='HKLM\A'; RegistryValueName='A'; ValueType='REG_DWORD'; Value='1'; SettingName='A' },
            [pscustomobject]@{ GPOName='GPO1'; Scope='User'; Category='Drive Maps'; RegistryKey=''; RegistryValueName=''; ValueType=''; Value='\\server\share'; SettingName='H:' }
        )

        Mock -CommandName Set-GPPrefRegistryValue
        Mock -CommandName ConvertTo-GPPreferenceXml -MockWith { '<Drives />' }
        Mock -CommandName Update-GPOVersion -MockWith { [pscustomobject]@{ Success = $true } }

        Import-PreferencePolicySetting -Rows $rows -GPOGuid '{11111111-1111-1111-1111-111111111111}' -Domain 'contoso.com'

        Should -Invoke Set-GPPrefRegistryValue -Times 1
        Should -Invoke ConvertTo-GPPreferenceXml -Times 1
        Should -Invoke Update-GPOVersion -Times 1
    }

    It 'skips XML categories without SYSVOL mapping' {
        $rows = @([pscustomobject]@{ GPOName='GPO1'; Scope='User'; Category='Unknown Category'; Value='x'; SettingName='x'; ValueType='REG_SZ'; RegistryKey=''; RegistryValueName='' })

        Mock -CommandName Update-GPOVersion
        Mock -CommandName Write-Warning

        Import-PreferencePolicySetting -Rows $rows -GPOGuid '{11111111-1111-1111-1111-111111111111}' -Domain 'contoso.com'

        Should -Invoke Update-GPOVersion -Times 0
        Should -Invoke Write-Warning -Times 1
    }
}
