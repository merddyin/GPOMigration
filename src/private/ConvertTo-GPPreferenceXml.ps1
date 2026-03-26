function ConvertTo-GPPreferenceXml {
    <#
    .SYNOPSIS
        Generates SYSVOL-compatible Preferences XML content for a given preference type
        from one or more setting rows.
    .DESCRIPTION
        Takes a collection of GPO setting rows (all belonging to the same Category and Scope)
        and produces the XML string that belongs in the corresponding Preferences XML file
        under SYSVOL (e.g. Drives.xml, Printers.xml, Registry.xml).

        The generated XML wraps each setting in a minimal valid element. For preference
        types whose XML schema requires additional fields not captured in the CSV (e.g.
        clsid GUIDs, action codes), sensible defaults are applied and documented inline.

        NOTE: The Windows Registry preference category is handled by Set-GPPrefRegistryValue
        via Import-PreferencePolicySetting and does NOT go through this function.
    .PARAMETER Rows
        One or more PSCustomObjects with the CSV/Excel schema columns.
    .PARAMETER Category
        The preference category name (must match $script:PreferenceSYSVOLMap key).
    .PARAMETER Scope
        'Computer' or 'User'.
    .OUTPUTS
        [string] XML content to be written to the Preferences XML file.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Rows,

        [Parameter(Mandatory)]
        [string]$Category,

        [Parameter(Mandatory)]
        [ValidateSet('Computer', 'User')]
        [string]$Scope
    )

    begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
    }

    process {
        # All preference XML files share a common root element pattern
        # The clsid attributes are stable GUIDs defined by the GP Schema (these are
        # the same on every Windows environment)
        $clsidMap = @{
            'Drive Maps'             = '{935D1B74-9CB8-4E3C-9914-7DD559B7A417}'
            'Printers'               = '{1F577D12-3D1B-471C-B1F5-6E914BDC9C60}'
            'Environment Variables'  = '{035BCEA0-71CB-11D1-8882-00C04FB6A2BF}'
            'Scheduled Tasks'        = '{AADCED64-746C-43EC-88FF-B1EA78E5E3A7}'
            'Services'               = '{91517B26-098D-4C01-84F9-2BC51689B861}'
            'Files'                  = '{50BE44C8-567A-4ED1-B1D0-9234FE1F38AF}'
            'Folders'                = '{6232C319-91AC-4931-9385-E70C2B099F0E}'
            'Shortcuts'              = '{17767FA8-8C75-4D11-AB76-F04B5573AA82}'
            'Data Sources'           = '{C80F98A3-9CA9-4C93-A1D6-1B23B84C5F7D}'
            'Ini Files'              = '{694EBF82-8B21-43D3-87E5-5A9A1E5245D6}'
            'Network Options'        = '{3A0CDDA7-97AE-4B4E-BE73-9C1B0A4E7F4D}'
            'Network Shares'         = '{520DA6A5-35F2-443B-9E0E-7BF64B4C3AE7}'
            'Local Users and Groups' = '{17E6CAB7-20D6-4F8C-8040-E9D97B4F5601}'
            'Devices'                = '{1A6364EB-776B-4120-B888-30B79F975D68}'
            'Folder Options'         = '{27DA6F51-DCA1-4E8C-9E29-87AFA45A5CF4}'
            'Power Options'          = '{E912EA82-3D44-47DC-A1B7-3A80CBFCE8A3}'
            'Start Menu'             = '{4BFF8B4E-9FE4-4A5C-BC19-A58B19E41E94}'
            'Regional Options'       = '{F0166B55-A8F0-4AEA-A44E-03BF1DB03834}'
            'Internet Options'       = '{E3F1B56A-49F6-4DC9-90F0-1D72CA5B0A1E}'
        }

        $rootClsid = if ($clsidMap.ContainsKey($Category)) { $clsidMap[$Category] } else { '{00000000-0000-0000-0000-000000000000}' }

        # Root element name maps to a known set for each preference type
        $rootElementMap = @{
            'Drive Maps'             = 'Drives'
            'Printers'               = 'Printers'
            'Environment Variables'  = 'EnvironmentVariables'
            'Scheduled Tasks'        = 'ScheduledTasks'
            'Services'               = 'NTServices'
            'Files'                  = 'Files'
            'Folders'                = 'Folders'
            'Shortcuts'              = 'Shortcuts'
            'Data Sources'           = 'DataSources'
            'Ini Files'              = 'IniFiles'
            'Network Options'        = 'NetworkOptions'
            'Network Shares'         = 'NetShares'
            'Local Users and Groups' = 'Groups'
            'Devices'                = 'Devices'
            'Folder Options'         = 'FolderOptions'
            'Power Options'          = 'PowerOptions'
            'Start Menu'             = 'StartMenu'
            'Regional Options'       = 'RegionalOptionsPolCfg'
            'Internet Options'       = 'InternetSettings'
        }

        $rootElement = if ($rootElementMap.ContainsKey($Category)) { $rootElementMap[$Category] } else { $Category -replace '\s', '' }

        $sb = [System.Text.StringBuilder]::new()
        $sb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>') | Out-Null
        $sb.AppendLine("<$rootElement clsid=`"$rootClsid`">") | Out-Null

        foreach ($row in $Rows) {
            $itemClsid = [System.Guid]::NewGuid().ToString('B').ToUpper()
            $uid       = [System.Guid]::NewGuid().ToString('B').ToUpper()
            $name      = [System.Security.SecurityElement]::Escape($row.SettingName)
            $value     = [System.Security.SecurityElement]::Escape($row.Value ?? '')
            $action    = 'U'  # Update — safe default for most preference types

            switch ($Category) {
                'Drive Maps' {
                    # path field is stored in Value column for Drive Maps
                    $sb.AppendLine("  <Drive clsid=`"$itemClsid`" name=`"$name`" status=`"$name`" image=`"1`" changed=`"2026-01-01 00:00:00`" uid=`"$uid`" userContext=`"0`" bypassErrors=`"1`">") | Out-Null
                    $sb.AppendLine("    <Properties action=`"$action`" thisDrive=`"NOCHANGE`" allDrives=`"NOCHANGE`" userName=`"`" path=`"$value`" label=`"`" persistent=`"1`" useLetter=`"1`" letter=`"$($name.Substring(0,1))`"/>") | Out-Null
                    $sb.AppendLine("  </Drive>") | Out-Null
                }
                'Printers' {
                    $sb.AppendLine("  <SharedPrinter clsid=`"$itemClsid`" name=`"$name`" status=`"$name`" image=`"1`" changed=`"2026-01-01 00:00:00`" uid=`"$uid`" userContext=`"0`" bypassErrors=`"1`">") | Out-Null
                    $sb.AppendLine("    <Properties action=`"$action`" comment=`"`" path=`"$value`" location=`"`" default=`"0`" skipLocal=`"0`" deleteAll=`"0`" persistent=`"0`" deleteMaps=`"0`" portMode=`"0`"/>") | Out-Null
                    $sb.AppendLine("  </SharedPrinter>") | Out-Null
                }
                'Environment Variables' {
                    $sb.AppendLine("  <EnvironmentVariable clsid=`"$itemClsid`" name=`"$name`" status=`"$name`" image=`"1`" changed=`"2026-01-01 00:00:00`" uid=`"$uid`" userContext=`"0`" bypassErrors=`"1`">") | Out-Null
                    $sb.AppendLine("    <Properties action=`"$action`" name=`"$name`" value=`"$value`" partial=`"0`"/>") | Out-Null
                    $sb.AppendLine("  </EnvironmentVariable>") | Out-Null
                }
                'Services' {
                    $sb.AppendLine("  <NTService clsid=`"$itemClsid`" name=`"$name`" status=`"$name`" image=`"1`" changed=`"2026-01-01 00:00:00`" uid=`"$uid`" bypassErrors=`"1`">") | Out-Null
                    $sb.AppendLine("    <Properties startupType=`"AUTOMATIC`" serviceName=`"$name`" serviceAction=`"START`" timeout=`"30`"/>") | Out-Null
                    $sb.AppendLine("  </NTService>") | Out-Null
                }
                'Files' {
                    $sb.AppendLine("  <File clsid=`"$itemClsid`" name=`"$name`" status=`"$name`" image=`"1`" changed=`"2026-01-01 00:00:00`" uid=`"$uid`" bypassErrors=`"1`">") | Out-Null
                    $sb.AppendLine("    <Properties action=`"$action`" fromPath=`"$value`" targetPath=`"$name`" readOnly=`"0`" archive=`"0`" hidden=`"0`"/>") | Out-Null
                    $sb.AppendLine("  </File>") | Out-Null
                }
                'Folders' {
                    $sb.AppendLine("  <Folder clsid=`"$itemClsid`" name=`"$name`" status=`"$name`" image=`"1`" changed=`"2026-01-01 00:00:00`" uid=`"$uid`" bypassErrors=`"1`">") | Out-Null
                    $sb.AppendLine("    <Properties action=`"$action`" path=`"$value`" readOnly=`"0`" archive=`"0`" hidden=`"0`" deleteIgnoreErrors=`"1`" deleteReadOnly=`"0`" deleteFiles=`"0`" deleteSubFolders=`"0`"/>") | Out-Null
                    $sb.AppendLine("  </Folder>") | Out-Null
                }
                'Shortcuts' {
                    $sb.AppendLine("  <Shortcut clsid=`"$itemClsid`" name=`"$name`" status=`"$name`" image=`"1`" changed=`"2026-01-01 00:00:00`" uid=`"$uid`" bypassErrors=`"1`">") | Out-Null
                    $sb.AppendLine("    <Properties action=`"$action`" shortcutKey=`"0`" targetType=`"FILESYSTEM`" iconIndex=`"0`" startIn=`"`" comment=`"`" targetPath=`"$value`" name=`"$name`" window=`"1`"/>") | Out-Null
                    $sb.AppendLine("  </Shortcut>") | Out-Null
                }
                'Scheduled Tasks' {
                    $sb.AppendLine("  <Task clsid=`"$itemClsid`" name=`"$name`" image=`"1`" changed=`"2026-01-01 00:00:00`" uid=`"$uid`" bypassErrors=`"1`">") | Out-Null
                    $sb.AppendLine("    <Properties action=`"$action`" name=`"$name`" appName=`"$value`" args=`"`" startIn=`"`" comment=`"`" enabled=`"1`" deleteWhenDone=`"0`" startOnlyIfIdle=`"0`" stopOnIdleEnd=`"0`" noStartIfOnBatteries=`"0`" stopIfGoingOnBatteries=`"0`" systemRequired=`"0`" runAs=`"NT AUTHORITY\System`" idleMinutes=`"10`" deadlineMinutes=`"60`" priority=`"7`" maxRunTime=`"259200000`"/>") | Out-Null
                    $sb.AppendLine("  </Task>") | Out-Null
                }
                default {
                    # Generic fallback — name/value pair wrapped in a Properties element
                    $elemName = $rootElement -replace 's$', ''  # naive singularise
                    $sb.AppendLine("  <$elemName clsid=`"$itemClsid`" name=`"$name`" status=`"$name`" image=`"1`" changed=`"2026-01-01 00:00:00`" uid=`"$uid`" bypassErrors=`"1`">") | Out-Null
                    $sb.AppendLine("    <Properties action=`"$action`" name=`"$name`" value=`"$value`"/>") | Out-Null
                    $sb.AppendLine("  </$elemName>") | Out-Null
                }
            }
        }

        $sb.AppendLine("</$rootElement>") | Out-Null
        $sb.ToString()
    }
}
