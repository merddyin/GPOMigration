function Resolve-RegistryMapping {
    <#
    .SYNOPSIS
        Resolves the RegistryKey, RegistryValueName, and ValueType for an Administrative
        Template setting by parsing the GPO's XML report.
    .DESCRIPTION
        Calls Get-GPOReport -ReportType XML for the specified GPO and parses the
        ExtensionData to find the registry key, value name, and data type that correspond
        to the given PolicyPath + SettingName combination.

        Results are cached in $script:GPOReportCache (keyed by GPO GUID) so that
        Get-GPOReport is only called once per GPO per session.

        Returns $null when no matching registry entry is found (e.g. the setting is
        a parent container rather than a leaf value).
    .PARAMETER GPOName
        Display name of the GPO.
    .PARAMETER GPOGuid
        GUID of the GPO (used as cache key).
    .PARAMETER Domain
        DNS domain of the GPO.
    .PARAMETER Scope
        'Computer' or 'User'.
    .PARAMETER SettingName
        The leaf setting name from ConvertFrom-SDMSettingPath.
    .PARAMETER PolicyPath
        The intermediate path from ConvertFrom-SDMSettingPath.
    .OUTPUTS
        [PSCustomObject] with RegistryKey (string), RegistryValueName (string),
        ValueType (string e.g. 'REG_DWORD'). Returns $null if not found.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$GPOName,

        [Parameter(Mandatory)]
        [string]$GPOGuid,

        [Parameter(Mandatory)]
        [string]$Domain,

        [Parameter(Mandatory)]
        [ValidateSet('Computer', 'User')]
        [string]$Scope,

        [Parameter(Mandatory)]
        [string]$SettingName,

        [Parameter()]
        [string]$PolicyPath = ''
    )

    begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
    }

    process {
        # Retrieve (or populate) cached XML report for this GPO
        if (-not $script:GPOReportCache.ContainsKey($GPOGuid)) {
            Write-Verbose "Resolve-RegistryMapping: fetching GPOReport XML for '$GPOName' ($GPOGuid)."
            try {
                $reportXml = Get-GPOReport -Name $GPOName -Domain $Domain -ReportType XML -ErrorAction Stop
                $script:GPOReportCache[$GPOGuid] = [xml]$reportXml
            } catch {
                Write-Warning "Resolve-RegistryMapping: Get-GPOReport failed for '$GPOName': $_"
                return $null
            }
        }

        $xmlDoc = $script:GPOReportCache[$GPOGuid]

        # Navigate to the correct scope element
        $ns = @{ gp = 'http://www.microsoft.com/GroupPolicy/Settings' }
        $scopeElement = if ($Scope -eq 'Computer') { 'Computer' } else { 'User' }

        # Namespace for registry extension data varies; search broadly with SelectNodes
        $nsManager = [System.Xml.XmlNamespaceManager]::new($xmlDoc.NameTable)
        $nsManager.AddNamespace('gp', 'http://www.microsoft.com/GroupPolicy/Settings')
        $nsManager.AddNamespace('reg', 'http://www.microsoft.com/GroupPolicy/Settings/Registry')

        # Find all Policy nodes under the correct scope
        $xpath = "//$scopeElement//reg:Policy[reg:Name='$SettingName']"
        $policyNodes = $xmlDoc.SelectNodes($xpath, $nsManager)

        if (-not $policyNodes -or $policyNodes.Count -eq 0) {
            # Try a broader search without namespace prefix (handles different report schemas)
            $xpath2 = "//$scopeElement//*[local-name()='Policy' and *[local-name()='Name' and .='$SettingName']]"
            $policyNodes = $xmlDoc.SelectNodes($xpath2)
        }

        if (-not $policyNodes -or $policyNodes.Count -eq 0) {
            Write-Verbose "Resolve-RegistryMapping: no XML match for SettingName='$SettingName' in '$GPOName'."
            return $null
        }

        # Use the first matching node
        $node = $policyNodes.Item(0)

        # Extract fields using local-name() to be schema-agnostic
        $keyNode   = $node.SelectSingleNode("*[local-name()='KeyName']")
        $valNode   = $node.SelectSingleNode("*[local-name()='ValueName']")
        $typeNode  = $node.SelectSingleNode("*[local-name()='Value']/*[local-name()='Element']/@type")
        if (-not $typeNode) {
            $typeNode = $node.SelectSingleNode("*[local-name()='Value']/@type")
        }

        if (-not $keyNode) {
            Write-Verbose "Resolve-RegistryMapping: KeyName element not found for '$SettingName'."
            return $null
        }

        # Normalise type to REG_* format
        $rawType = if ($typeNode) { $typeNode.Value ?? $typeNode.InnerText } else { '' }
        $valueType = switch -Wildcard ($rawType) {
            '*String'       { 'REG_SZ' }
            '*DWord'        { 'REG_DWORD' }
            '*QWord'        { 'REG_QWORD' }
            '*ExpandString' { 'REG_EXPAND_SZ' }
            '*MultiString'  { 'REG_MULTI_SZ' }
            '*Binary'       { 'REG_BINARY' }
            default         { $rawType }
        }

        [PSCustomObject]@{
            RegistryKey       = $keyNode.InnerText.Trim()
            RegistryValueName = if ($valNode) { $valNode.InnerText.Trim() } else { '' }
            ValueType         = $valueType
        }
    }
}
