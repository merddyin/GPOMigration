Set-StrictMode -Version Latest

Describe 'Import-RegistryPolicySetting' -Tag 'UnitTest' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\..\..\src\other\PreLoad.ps1')
        . (Join-Path $PSScriptRoot '..\..\..\src\private\Get-CallerPreference.ps1')
        . (Join-Path $PSScriptRoot '..\..\..\src\private\Import-RegistryPolicySetting.ps1')

        # Ensure command exists so Mock/Should-Invoke work on runners without GroupPolicy RSAT.
        function Set-GPRegistryValue { }
    }

    It 'calls Set-GPRegistryValue for computer scope with typed DWORD value' {
        $row = [pscustomobject]@{
            GPOName='GPO1'; Domain='contoso.com'; Scope='Computer'; SettingName='A';
            RegistryKey='HKLM\Software\Policies\Contoso'; RegistryValueName='A'; ValueType='REG_DWORD'; Value='10'
        }
        Mock -CommandName Set-GPRegistryValue

        Import-RegistryPolicySetting -Row $row

        Should -Invoke Set-GPRegistryValue -Times 1
    }

    It 'calls Set-GPRegistryValue with user switch for user scope' {
        $row = [pscustomobject]@{
            GPOName='GPO1'; Domain='contoso.com'; Scope='User'; SettingName='A';
            RegistryKey='HKCU\Software\Policies\Contoso'; RegistryValueName='A'; ValueType='REG_SZ'; Value='abc'
        }
        Mock -CommandName Set-GPRegistryValue

        Import-RegistryPolicySetting -Row $row

        Should -Invoke Set-GPRegistryValue -Times 1
    }

    It 'skips when RegistryKey is missing' {
        $row = [pscustomobject]@{
            GPOName='GPO1'; Domain='contoso.com'; Scope='Computer'; SettingName='A';
            RegistryKey=''; RegistryValueName='A'; ValueType='REG_SZ'; Value='abc'
        }
        Mock -CommandName Set-GPRegistryValue
        Mock -CommandName Write-Warning

        Import-RegistryPolicySetting -Row $row

        Should -Invoke Set-GPRegistryValue -Times 0
        Should -Invoke Write-Warning -Times 1
    }
}
