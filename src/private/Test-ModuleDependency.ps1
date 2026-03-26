function Test-ModuleDependency {
    <#
    .SYNOPSIS
        Validates that all runtime dependencies required by GPOMigration are available.
    .DESCRIPTION
        Checks for the GroupPolicy RSAT module, the SDM-GPMC plugin module, and the
        OfficeIMO.Excel assembly. Returns a result object for each dependency. Throws a
        terminating error if any required dependency is unavailable.
    .OUTPUTS
        [PSCustomObject[]]  Each object has: Name, Available (bool), Required (bool), Message.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param()

    begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
    }

    process {
        $results = [System.Collections.Generic.List[PSCustomObject]]::new()

        # --- GroupPolicy RSAT ---
        $gpModule = Get-Module -Name 'GroupPolicy' -ErrorAction SilentlyContinue
        $gpAvailable = $null -ne $gpModule
        $results.Add([PSCustomObject]@{
            Name      = 'GroupPolicy'
            Available = $gpAvailable
            Required  = $true
            Message   = if ($gpAvailable) { "Loaded (v$($gpModule.Version))" } else { 'Not loaded. Install RSAT Group Policy Management Tools and ensure GroupPolicy is in RequiredModules.' }
        })

        # --- SDM-GPMC plugin ---
        $sdmModule = Get-Module -Name 'SDM-GPMC' -ErrorAction SilentlyContinue
        $sdmAvailable = $null -ne $sdmModule
        $results.Add([PSCustomObject]@{
            Name      = 'SDM-GPMC'
            Available = $sdmAvailable
            Required  = $true
            Message   = if ($sdmAvailable) { "Loaded (v$($sdmModule.Version))" } else { 'Not loaded. Ensure plugins/sdm-gpmc/Load.ps1 ran during module import.' }
        })

        # --- OfficeIMO.Excel assembly ---
        $officeImoAvailable = $script:OfficeIMOLoaded -eq $true
        if ($officeImoAvailable) {
            # Verify the key type actually resolves
            $resolvedType = [System.AppDomain]::CurrentDomain.GetAssemblies() |
                Where-Object { $_.GetName().Name -eq 'OfficeIMO.Excel' } |
                Select-Object -First 1
            $officeImoAvailable = $null -ne $resolvedType
        }
        $results.Add([PSCustomObject]@{
            Name      = 'OfficeIMO.Excel'
            Available = $officeImoAvailable
            Required  = $true
            Message   = if ($officeImoAvailable) { 'Assembly loaded.' } else { 'Not loaded. Ensure plugins/OfficeIMO/Load.ps1 ran during module import and all DLLs are present in plugins/OfficeIMO/lib/.' }
        })

        $missing = $results | Where-Object { $_.Required -and -not $_.Available }
        if ($missing) {
            $detail = ($missing | ForEach-Object { "  [$($_.Name)] $($_.Message)" }) -join "`n"
            throw "GPOMigration: one or more required dependencies are unavailable:`n$detail"
        }

        $results
    }
}
