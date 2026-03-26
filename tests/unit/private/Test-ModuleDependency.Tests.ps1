Set-StrictMode -Version Latest

Describe 'Test-ModuleDependency' -Tag 'UnitTest' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\..\..\src\private\Get-CallerPreference.ps1')
        . (Join-Path $PSScriptRoot '..\..\..\src\private\Test-ModuleDependency.ps1')
    }

    It 'throws when required modules are not loaded' {
        $script:OfficeIMOLoaded = $false
        Mock -CommandName Get-Module -MockWith { $null }

        { Test-ModuleDependency } | Should -Throw
    }

    It 'throws when OfficeIMO is not loaded even if modules are loaded' {
        $script:OfficeIMOLoaded = $false
        Mock -CommandName Get-Module -ParameterFilter { $Name -eq 'GroupPolicy' } -MockWith { [pscustomobject]@{ Version = '1.0.0' } }
        Mock -CommandName Get-Module -ParameterFilter { $Name -eq 'SDM-GPMC' } -MockWith { [pscustomobject]@{ Version = '2.1.0' } }

        { Test-ModuleDependency } | Should -Throw
    }
}
