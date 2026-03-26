<#
 Module-scoped constants initialised before any function is dot-sourced.
 Do not reference module functions here — they have not been loaded yet.
#>

# SDM-GPMC Areas that map to Administrative Templates (registry-backed policy)
$script:AdminTemplateAreas = @('Registry')

# SDM-GPMC Areas that map to Group Policy Preferences
$script:PreferenceAreas = @(
    'Environment Variables',
    'Local Users and Groups',
    'Devices',
    'Network Options',
    'Folders',
    'Network Shares',
    'Files',
    'Data Sources',
    'Ini Files',
    'Services',
    'Folder Options',
    'Scheduled Tasks',
    'Windows Registry',
    'Printers',
    'Shortcuts',
    'Power Options',
    'Drive Maps',
    'Start Menu',
    'Regional Options',
    'Internet Options'
)

$script:AllSupportedAreas = $script:AdminTemplateAreas + $script:PreferenceAreas

# Maps ValueType string (CSV/Excel column) to [Microsoft.Win32.RegistryValueKind]
$script:RegistryTypeMap = @{
    'REG_SZ'        = [Microsoft.Win32.RegistryValueKind]::String
    'REG_DWORD'     = [Microsoft.Win32.RegistryValueKind]::DWord
    'REG_QWORD'     = [Microsoft.Win32.RegistryValueKind]::QWord
    'REG_EXPAND_SZ' = [Microsoft.Win32.RegistryValueKind]::ExpandString
    'REG_MULTI_SZ'  = [Microsoft.Win32.RegistryValueKind]::MultiString
    'REG_BINARY'    = [Microsoft.Win32.RegistryValueKind]::Binary
    'REG_NONE'      = [Microsoft.Win32.RegistryValueKind]::None
}

# Maps SDM preference area name to the SYSVOL Preferences subfolder name
$script:PreferenceSYSVOLMap = @{
    'Environment Variables'  = 'EnvironmentVariables'
    'Local Users and Groups' = 'Groups'
    'Devices'                = 'Devices'
    'Network Options'        = 'NetworkOptions'
    'Folders'                = 'Folders'
    'Network Shares'         = 'NetworkShares'
    'Files'                  = 'Files'
    'Data Sources'           = 'DataSources'
    'Ini Files'              = 'IniFiles'
    'Services'               = 'Services'
    'Folder Options'         = 'FolderOptions'
    'Scheduled Tasks'        = 'ScheduledTasks'
    'Windows Registry'       = 'Registry'
    'Printers'               = 'Printers'
    'Shortcuts'              = 'Shortcuts'
    'Power Options'          = 'PowerOptions'
    'Drive Maps'             = 'Drives'
    'Start Menu'             = 'StartMenu'
    'Regional Options'       = 'RegionalOptionsPolCfg'
    'Internet Options'       = 'InternetSettings'
}

# Maps SDM preference area name to the Preferences XML filename written to SYSVOL
$script:PreferenceXmlFileMap = @{
    'Environment Variables'  = 'EnvironmentVariables.xml'
    'Local Users and Groups' = 'Groups.xml'
    'Devices'                = 'Devices.xml'
    'Network Options'        = 'NetworkOptions.xml'
    'Folders'                = 'Folders.xml'
    'Network Shares'         = 'NetworkShares.xml'
    'Files'                  = 'Files.xml'
    'Data Sources'           = 'DataSources.xml'
    'Ini Files'              = 'IniFiles.xml'
    'Services'               = 'Services.xml'
    'Folder Options'         = 'FolderOptions.xml'
    'Scheduled Tasks'        = 'ScheduledTasks.xml'
    'Windows Registry'       = 'Registry.xml'
    'Printers'               = 'Printers.xml'
    'Shortcuts'              = 'Shortcuts.xml'
    'Power Options'          = 'PowerOptions.xml'
    'Drive Maps'             = 'Drives.xml'
    'Start Menu'             = 'StartMenu.xml'
    'Regional Options'       = 'RegionalOptionsPolCfg.xml'
    'Internet Options'       = 'InternetSettings.xml'
}

# GUID-keyed cache for Get-GPOReport XML results (populated by Resolve-RegistryMapping)
$script:GPOReportCache = @{}

# Set to $true by plugins/OfficeIMO/Load.ps1 after successful assembly load
$script:OfficeIMOLoaded = $false