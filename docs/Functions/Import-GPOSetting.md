# Import-GPOSetting

## Synopsis
Imports GPOMigration settings from CSV or Excel files into GPOs.

## Description
`Import-GPOSetting` reads one or more migration files and applies settings to existing or newly created GPOs.

- Administrative Template rows are applied with `Set-GPRegistryValue` through internal helpers.
- Preference rows are applied through Group Policy Preference registry cmdlets or SYSVOL XML generation.
- If a user is not Domain Admin for SYSVOL writes, preference XML is staged in a local fallback folder.

## Syntax
```powershell
Import-GPOSetting -Path <string[]> [-GPOName <string>] [-Domain <string>] [-CreateIfMissing] [-LocalFallbackPath <string>]
```

## Parameters
- `Path`: CSV/XLSX file path(s) or folder path(s).
- `GPOName`: Optional override for the target GPO name.
- `Domain`: DNS domain for target GPO operations.
- `CreateIfMissing`: Creates target GPOs that do not exist.
- `LocalFallbackPath`: Local staging path used when SYSVOL writes cannot be performed.

## Outputs
None.

## Examples
```powershell
Import-GPOSetting -Path C:\Export\MyGPO.csv -GPOName 'Production Policy'
```

```powershell
Import-GPOSetting -Path C:\Export\GPOSettings.xlsx -CreateIfMissing -WhatIf
```
