Set-StrictMode -Version Latest

Describe 'Export-GPOSetting' -Tag 'UnitTest' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\..\..\src\other\PreLoad.ps1')
        . (Join-Path $PSScriptRoot '..\..\..\src\private\Get-CallerPreference.ps1')
        . (Join-Path $PSScriptRoot '..\..\..\src\public\Export-GPOSetting.ps1')

        function Test-ModuleDependency { }
        function Out-SDMGPSettings { }
        function ConvertFrom-SDMSettingPath { }
        function Resolve-RegistryMapping { }
        function Get-GPO { }
        function Export-Csv { }
    }

    It 'exports parsed rows to CSV' {
        Mock -CommandName Test-ModuleDependency
        Mock -CommandName Test-Path -MockWith { $true }
        Mock -CommandName Out-SDMGPSettings -MockWith {
            @([pscustomobject]@{ SettingPath = 'Computer Configuration|Administrative Templates|Windows|SettingA'; SettingValue = '1' })
        }
        Mock -CommandName ConvertFrom-SDMSettingPath -MockWith {
            [pscustomobject]@{
                GPOName = 'GPO1'; GPOGuid = '{11111111-1111-1111-1111-111111111111}'; Domain = 'contoso.com'; Scope = 'Computer';
                Category = 'Registry'; PolicyPath = 'Windows'; SettingName = 'SettingA'; Value = '1';
                ValueType = ''; RegistryKey = ''; RegistryValueName = ''; State = ''
            }
        }
        Mock -CommandName Get-GPO -MockWith {
            [pscustomobject]@{ DisplayName = 'GPO1'; Id = [guid]'11111111-1111-1111-1111-111111111111' }
        }
        Mock -CommandName Export-Csv

        Export-GPOSetting -DisplayName 'GPO1' -OutputPath (Join-Path $TestDrive 'out') -OutputFormat CSV -Confirm:$false

        Should -Invoke Out-SDMGPSettings -Times 1
        Should -Invoke ConvertFrom-SDMSettingPath -Times 1
        Should -Invoke Export-Csv -Times 1
    }

    It 'resolves registry mapping when IncludeRegistryMapping is set' {
        Mock -CommandName Test-ModuleDependency
        Mock -CommandName Test-Path -MockWith { $true }
        Mock -CommandName Get-GPO -MockWith {
            [pscustomobject]@{ DisplayName = 'GPO1'; Id = [guid]'11111111-1111-1111-1111-111111111111' }
        }
        Mock -CommandName Out-SDMGPSettings -MockWith {
            @([pscustomobject]@{ SettingPath = 'Computer Configuration|Administrative Templates|Windows|SettingA'; SettingValue = '1' })
        }
        Mock -CommandName ConvertFrom-SDMSettingPath -MockWith {
            [pscustomobject]@{
                GPOName = 'GPO1'; GPOGuid = '{11111111-1111-1111-1111-111111111111}'; Domain = 'contoso.com'; Scope = 'Computer';
                Category = 'Registry'; PolicyPath = 'Windows'; SettingName = 'SettingA'; Value = '1';
                ValueType = ''; RegistryKey = ''; RegistryValueName = ''; State = ''
            }
        }
        Mock -CommandName Resolve-RegistryMapping -MockWith {
            [pscustomobject]@{ RegistryKey = 'HKLM\Software\Policies'; RegistryValueName = 'SettingA'; ValueType = 'REG_DWORD' }
        }
        Mock -CommandName Export-Csv

        { Export-GPOSetting -DisplayName 'GPO1' -OutputPath (Join-Path $TestDrive 'out') -OutputFormat CSV -IncludeRegistryMapping -Confirm:$false } | Should -Not -Throw
    }

    It 'does not export data when WhatIf is used' {
        Mock -CommandName Test-ModuleDependency
        Mock -CommandName Test-Path -MockWith { $true }
        Mock -CommandName Out-SDMGPSettings

        Export-GPOSetting -DisplayName 'GPO1' -OutputPath (Join-Path $TestDrive 'out3') -OutputFormat CSV -WhatIf

        Should -Invoke Out-SDMGPSettings -Times 0
    }
}
