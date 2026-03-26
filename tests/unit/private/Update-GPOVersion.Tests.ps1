Set-StrictMode -Version Latest

Describe 'Update-GPOVersion helper behavior' -Tag 'UnitTest' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\..\..\src\other\PreLoad.ps1')
        . (Join-Path $PSScriptRoot '..\..\..\src\private\Get-CallerPreference.ps1')
        . (Join-Path $PSScriptRoot '..\..\..\src\private\Update-GPOVersion.ps1')
    }

    It 'throws for category without SYSVOL mapping' {
        { Update-GPOVersion -GPOGuid '{1}' -Domain 'contoso.com' -Scope Computer -Category 'Unknown' -XmlContent '<x />' } | Should -Throw
    }

    It 'increments machine version for computer scope' {
        $gpt = Join-Path $TestDrive 'gpt.ini'
        Set-Content -LiteralPath $gpt -Value "[General]`r`nVersion=0`r`n" -Encoding UTF8

        $newVersion = Update-GptIniVersion -GptIniPath $gpt -Scope Computer

        $newVersion | Should -Be 1
        (Get-Content -LiteralPath $gpt -Raw) | Should -Match 'Version=1'
    }

    It 'increments user half for user scope' {
        $gpt = Join-Path $TestDrive 'gpt2.ini'
        Set-Content -LiteralPath $gpt -Value "[General]`r`nVersion=0`r`n" -Encoding UTF8

        $newVersion = Update-GptIniVersion -GptIniPath $gpt -Scope User

        $newVersion | Should -Be 65536
        (Get-Content -LiteralPath $gpt -Raw) | Should -Match 'Version=65536'
    }
}
