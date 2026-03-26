Set-StrictMode -Version Latest

Describe 'PostLoad script safety' -Tag 'UnitTest' {
    It 'throws outside module scope due to OnRemove assignment' {
        $tempRoot = Join-Path $TestDrive 'module'
        $otherDir = Join-Path $tempRoot 'src\other'
        New-Item -ItemType Directory -Path $otherDir -Force | Out-Null

        $content = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\..\..\src\other\PostLoad.ps1') -Raw
        Set-Content -LiteralPath (Join-Path $otherDir 'PostLoad.ps1') -Value $content -Encoding UTF8

        { . (Join-Path $otherDir 'PostLoad.ps1') } | Should -Throw
    }
}
