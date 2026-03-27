Set-StrictMode -Version Latest

Describe 'Resolve-RegistryMapping' -Tag 'UnitTest' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\..\..\src\private\Get-CallerPreference.ps1')
        . (Join-Path $PSScriptRoot '..\..\..\src\private\Resolve-RegistryMapping.ps1')

    # Ensure command exists so Mock/Should-Invoke work on runners without GroupPolicy RSAT.
    function Get-GPOReport { }
    }

    BeforeEach {
        $script:GPOReportCache = @{}
    }

    It 'returns registry mapping from GPO report xml' {
        $xml = @'
<GPO xmlns:reg="http://www.microsoft.com/GroupPolicy/Settings/Registry">
  <Computer>
    <reg:Policy>
      <reg:Name>Policy A</reg:Name>
      <reg:KeyName>HKLM\Software\Policies\Contoso</reg:KeyName>
      <reg:ValueName>ValueA</reg:ValueName>
      <reg:Value>
        <reg:Element type="DWord" />
      </reg:Value>
    </reg:Policy>
  </Computer>
</GPO>
'@
        Mock -CommandName Get-GPOReport -MockWith { $xml }

        $result = Resolve-RegistryMapping -GPOName 'GPO1' -GPOGuid '{1}' -Domain 'contoso.com' -Scope Computer -SettingName 'Policy A'

        $result.RegistryKey | Should -Be 'HKLM\Software\Policies\Contoso'
        $result.RegistryValueName | Should -Be 'ValueA'
        $result.ValueType | Should -Be 'REG_DWORD'
    }

    It 'uses cache and does not refetch report when guid is already present' {
        $script:GPOReportCache['{1}'] = [xml]@'
<GPO xmlns:reg="http://www.microsoft.com/GroupPolicy/Settings/Registry"><Computer/></GPO>
'@
        Mock -CommandName Get-GPOReport

        $null = Resolve-RegistryMapping -GPOName 'GPO1' -GPOGuid '{1}' -Domain 'contoso.com' -Scope Computer -SettingName 'Missing'

        Should -Invoke Get-GPOReport -Times 0
    }
}
