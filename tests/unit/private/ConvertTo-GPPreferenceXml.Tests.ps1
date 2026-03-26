Set-StrictMode -Version Latest

Describe 'ConvertTo-GPPreferenceXml' -Tag 'UnitTest' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\..\..\src\private\Get-CallerPreference.ps1')
        . (Join-Path $PSScriptRoot '..\..\..\src\private\ConvertTo-GPPreferenceXml.ps1')
    }

    It 'builds Drive Maps XML structure' {
        $rows = @([pscustomobject]@{ SettingName='H:'; Value='\\server\share' })

        $xml = ConvertTo-GPPreferenceXml -Rows $rows -Category 'Drive Maps' -Scope User

        $xml | Should -Match '<Drives'
        $xml | Should -Match '<Drive '
        $xml | Should -Match 'path=".*share"'
    }

    It 'escapes xml-sensitive values' {
        $rows = @([pscustomobject]@{ SettingName='A&B'; Value='x<y' })

        $xml = ConvertTo-GPPreferenceXml -Rows $rows -Category 'Environment Variables' -Scope User

        $xml | Should -Match 'A&amp;B'
        $xml | Should -Match 'x&lt;y'
    }
}
