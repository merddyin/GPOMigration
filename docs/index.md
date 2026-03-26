# GPOMigration
Exports and Imports GPO settings and values to-from a CSV file.

Project Site: [https://github.com/merddyin/GPOMigration](https://github.com/merddyin/GPOMigration)

## What is GPOMigration?
Exports and Imports GPO settings and values to-from a CSV file.

## Why use the GPOMigration Module?
GPOMigration makes Group Policy migration practical when teams need repeatable and reviewable changes.

- Export live GPO settings into human-readable CSV or Excel formats.
- Review, diff, and hand-edit settings before importing to another environment.
- Re-apply both Administrative Template and supported Group Policy Preference settings with a consistent schema.
- Stage preference XML safely for manual SYSVOL copy when not running with Domain Admin privileges.

### Features
- Export by GPO name or GUID.
- CSV and Excel output options for migration data.
- Optional registry mapping enrichment for Administrative Template re-import fidelity.
- Template generation for new migration files.
- Settings comparison between exports.
- Import to existing GPOs or create missing GPOs on demand.

## Installation
Download the latest package from the repository [Releases](https://github.com/merddyin/GPOMigration/releases) page.

1. Download the zip artifact for the version you want.
2. Extract the archive.
3. Copy the extracted `GPOMigration/<version>` contents to one of your module paths. For current-user installs, use:

```powershell
New-Item -Path "$HOME\Documents\PowerShell\Modules\GPOMigration" -ItemType Directory -Force | Out-Null
Copy-Item -Path "<unzipped path>\GPOMigration\<version>\*" -Destination "$HOME\Documents\PowerShell\Modules\GPOMigration" -Recurse -Force
```

4. Add module import to your profile if desired:

```powershell
if (-not (Test-Path $PROFILE)) { New-Item -Path $PROFILE -ItemType File -Force | Out-Null }
Add-Content -Path $PROFILE -Value "Import-Module GPOMigration"
```

## Contributing
[Notes on contributing to this project](Contributing.md)

## Change Logs
[Change notes for each release](ChangeLog.md)

## Acknowledgements
[Other projects or sources of inspiration](Acknowledgements.md)


