# New-GPOMigrationTemplate

## Synopsis
Creates a blank or sample GPOMigration template file.

## Description
`New-GPOMigrationTemplate` creates a CSV or Excel file with the expected import schema columns. Optionally, it adds example rows for one Administrative Template setting and one Drive Maps preference.

Use this command to bootstrap a hand-authored migration file for `Import-GPOSetting`.

## Syntax
```powershell
New-GPOMigrationTemplate -OutputPath <string> [-OutputFormat <string>] [-IncludeExamples]
```

## Parameters
- `OutputPath`: File path for the template to create.
- `OutputFormat`: `CSV` or `Excel`.
- `IncludeExamples`: Adds example rows to illustrate expected values.

## Outputs
None.

## Examples
```powershell
New-GPOMigrationTemplate -OutputPath C:\Templates\MyTemplate.csv
```

```powershell
New-GPOMigrationTemplate -OutputPath C:\Templates\MyTemplate.xlsx -OutputFormat Excel -IncludeExamples
```
