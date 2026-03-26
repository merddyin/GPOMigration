Set-StrictMode -Version Latest

Describe 'Import-GPOSetting' -Tag 'UnitTest' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\..\..\src\other\PreLoad.ps1')
        . (Join-Path $PSScriptRoot '..\..\..\src\private\Get-CallerPreference.ps1')
        . (Join-Path $PSScriptRoot '..\..\..\src\public\Import-GPOSetting.ps1')

        function Test-ModuleDependency { }
        function Import-RegistryPolicySetting { }
        function Import-PreferencePolicySetting { }
        function Get-GPO { }
        function New-GPO { }
        function Import-Csv { }
    }

    It 'routes admin and preference rows to their handlers for existing GPO' {
        Mock -CommandName Test-ModuleDependency
        Mock -CommandName Test-Path -ParameterFilter { $PathType -eq 'Leaf' } -MockWith { $true }
        Mock -CommandName Test-Path -ParameterFilter { $PathType -eq 'Container' } -MockWith { $false }
        Mock -CommandName Import-Csv -MockWith {
            @(
                [pscustomobject]@{ GPOName='GPO1'; Category='Registry'; RegistryKey='HKLM\A'; SettingName='A'; Scope='Computer'; Domain='contoso.com' },
                [pscustomobject]@{ GPOName='GPO1'; Category='Drive Maps'; RegistryKey=''; SettingName='B'; Scope='User'; Domain='contoso.com' }
            )
        }
        Mock -CommandName Get-GPO -MockWith { [pscustomobject]@{ Id = [guid]'11111111-1111-1111-1111-111111111111' } }
        Mock -CommandName Import-RegistryPolicySetting
        Mock -CommandName Import-PreferencePolicySetting

        Import-GPOSetting -Path 'input.csv' -Domain 'contoso.com' -Confirm:$false

        Should -Invoke Import-RegistryPolicySetting -Times 1
        Should -Invoke Import-PreferencePolicySetting -Times 1
    }

    It 'creates missing GPO when CreateIfMissing is specified' {
        Mock -CommandName Test-ModuleDependency
        Mock -CommandName Test-Path -ParameterFilter { $PathType -eq 'Leaf' } -MockWith { $true }
        Mock -CommandName Test-Path -ParameterFilter { $PathType -eq 'Container' } -MockWith { $false }
        Mock -CommandName Import-Csv -MockWith {
            @([pscustomobject]@{ GPOName='GPO2'; Category='Drive Maps'; RegistryKey=''; SettingName='B'; Scope='User'; Domain='contoso.com' })
        }
        Mock -CommandName Get-GPO -MockWith { $null }
        Mock -CommandName New-GPO -MockWith { [pscustomobject]@{ Id = [guid]'22222222-2222-2222-2222-222222222222' } }
        Mock -CommandName Import-PreferencePolicySetting

        Import-GPOSetting -Path 'input.csv' -Domain 'contoso.com' -CreateIfMissing -Confirm:$false

        Should -Invoke New-GPO -Times 1
        Should -Invoke Import-PreferencePolicySetting -Times 1
    }

    It 'skips xlsx files with warning' {
        Mock -CommandName Test-ModuleDependency
        Mock -CommandName Test-Path -ParameterFilter { $PathType -eq 'Leaf' } -MockWith { $true }
        Mock -CommandName Test-Path -ParameterFilter { $PathType -eq 'Container' } -MockWith { $false }
        Mock -CommandName Write-Warning

        Import-GPOSetting -Path 'input.xlsx' -Domain 'contoso.com' -Confirm:$false

        Should -Invoke Write-Warning -Times 1 -ParameterFilter { $Message -like '*Excel file reading is not yet implemented*' }
    }
}
