# Compare-GPOSetting

## Synopsis
Compares two GPOMigration export files and returns row-level differences.

## Description
`Compare-GPOSetting` reads two export files (CSV supported; XLSX currently warns and returns no rows) and compares settings using a key built from one or more columns. Output rows include a `SideIndicator` value:

- `<=` exists only in the reference file
- `=>` exists only in the difference file
- `==` exists in both files for the selected key

## Syntax
```powershell
Compare-GPOSetting -ReferencePath <string> -DifferencePath <string> [-Property <string[]>]
```

## Parameters
- `ReferencePath`: Path to the baseline CSV or XLSX file.
- `DifferencePath`: Path to the comparison CSV or XLSX file.
- `Property`: Column names used as the comparison key. Defaults to `GPOName`, `PolicyPath`, `SettingName`, `Value`, and `Category`.

## Outputs
`[PSCustomObject[]]` with `PSTypeName = GPOMigration.ComparisonResult`.

## Examples
```powershell
Compare-GPOSetting -ReferencePath C:\Export\Baseline.csv -DifferencePath C:\Export\Current.csv
```

```powershell
Compare-GPOSetting -ReferencePath C:\Export\Baseline.csv -DifferencePath C:\Export\Current.csv -Property GPOName,PolicyPath,SettingName
```
