Set-StrictMode -Version Latest

Describe 'PreLoad initialization' -Tag 'UnitTest' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\..\..\src\other\PreLoad.ps1')
    }

    It 'initializes supported area lists and maps' {
        $script:AdminTemplateAreas | Should -Contain 'Registry'
        $script:PreferenceAreas.Count | Should -BeGreaterThan 0
        $script:AllSupportedAreas | Should -Contain 'Drive Maps'
        $script:PreferenceSYSVOLMap['Drive Maps'] | Should -Be 'Drives'
        $script:PreferenceXmlFileMap['Drive Maps'] | Should -Be 'Drives.xml'
    }

    It 'initializes OfficeIMO loaded flag to false by default' {
        $script:OfficeIMOLoaded | Should -BeFalse
    }
}
