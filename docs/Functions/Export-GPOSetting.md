# Export-GPOSetting

## Synopsis
Exports Group Policy Object settings to CSV or Excel.

## Description
`Export-GPOSetting` queries supported Administrative Template and Group Policy Preference settings using SDM-GPMC and writes them to migration files.

- `CSV` output creates one file per GPO.
- `Excel` output creates one workbook with one sheet per GPO.
- `IncludeRegistryMapping` enriches Administrative Template rows with registry metadata required for re-import.

## Syntax
```powershell
Export-GPOSetting -DisplayName <string[]> -OutputPath <string> [-Domain <string>] [-OutputFormat <string>] [-IncludeRegistryMapping]

Export-GPOSetting -Id <string[]> -OutputPath <string> [-Domain <string>] [-OutputFormat <string>] [-IncludeRegistryMapping]
```

## Parameters
- `DisplayName`: One or more GPO names to export.
- `Id`: One or more GPO GUIDs to export.
- `Domain`: DNS domain to query. Defaults to current domain.
- `OutputPath`: Destination folder for export files.
- `OutputFormat`: `CSV` or `Excel`.
- `IncludeRegistryMapping`: Populates `RegistryKey`, `RegistryValueName`, and `ValueType` for admin template rows.

## Outputs
None.

## Examples
```powershell
Export-GPOSetting -DisplayName 'Default Domain Policy' -OutputPath C:\Export
```

```powershell
Get-GPO -All | Export-GPOSetting -OutputPath C:\Export -OutputFormat Excel -IncludeRegistryMapping
```
