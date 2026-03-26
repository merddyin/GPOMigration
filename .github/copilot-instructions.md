# GitHub Copilot Instructions — GPOMigration

## Project Purpose

GPOMigration is a PowerShell 7+ module for exporting and importing Group Policy Object settings.
It reads settings from live GPOs and writes them to CSV or Excel files in a human-readable,
hand-craftable format, then re-applies those settings back to new or existing GPOs.

See `docs/ImplementationPlan.md` for the full implementation plan with status tracking.

---

## Scope — What This Module Handles

**Supported:** Administrative Templates (registry-backed), Extra Registry Settings, and all
Group Policy Preference types:

- Drive Maps, Printers, Environment Variables, Windows Registry, Services, Scheduled Tasks
- Files, Folders, Shortcuts, Data Sources, Ini Files, Network Shares, Network Options
- Power Options, Folder Options, Local Users and Groups, Devices
- Start Menu, Regional Options, Internet Options

**Not supported:** Software Settings, Windows Settings (Security, Scripts, Folder Redirection,
Firewall, QoS, IP Security, Public Key Policy, Audit Policy), SID/value translation, GPO links,
GPO permissions, WMI filters.

---

## Technology Stack

| Component | Role | Notes |
|---|---|---|
| **PowerShell 7.0+** | Runtime | Minimum version — required in manifest |
| **SDM-GPMC v2.1** | Read GPO settings | Bundled plugin at `plugins/sdm-gpmc/` |
| **GroupPolicy** (RSAT) | Write GPO settings | RequiredModules entry; not redistributable |
| **OfficeIMO.Excel** (MIT) | Excel file I/O | Bundled in `plugins/OfficeIMO/lib/`; always available |
| **Pester 5** | Tests | Unit + integration test suite |
| **InvokeBuild** | Build | `Build.ps1` + `GPOMigration.build.ps1` |

---

## Architecture

### Module Loading Order (GPOMigration.psm1)

1. `src/other/PreLoad.ps1` — module-scoped constants
2. `src/private/*.ps1` — private helper functions
3. `src/public/*.ps1` — public exported functions (auto-discovered via AST)
4. `src/other/PostLoad.ps1` — iterates `plugins/*/Load.ps1` to load SDM-GPMC and OfficeIMO

### Plugin System

`src/other/PostLoad.ps1` iterates every subdirectory under `plugins/` and dot-sources `Load.ps1`
and `UnLoad.ps1` via `Invoke-Command -NoNewScope`. Plugins run in module scope.

### OfficeIMO Assembly Loading

`plugins/OfficeIMO/Load.ps1` loads all DLLs from `plugins/OfficeIMO/lib/` using
`[System.Reflection.Assembly]::LoadFrom()`. It skips any assembly whose short name is already
loaded to avoid duplicate conflicts. The flag `$script:OfficeIMOLoaded = $true` is set on success.
OfficeIMO is always bundled — treat a missing DLL as a hard error, not a graceful fallback.

### SDM-GPMC Key Cmdlets

- `Out-SDMGPSettings -DisplayName <name> -Domain <domain> -Areas <string[]>` — returns objects
  with `Domain`, `DisplayName`, `SettingPath` (pipe-delimited path), `SettingValue`
- `Get-SDMgpo -DisplayName <name>` — returns GPO metadata
- `Out-SDMgpsettingsreport` — XML/HTML report output

### GroupPolicy RSAT Key Cmdlets

- `Set-GPRegistryValue` — Admin Template / registry setting write
- `Set-GPPrefRegistryValue` — Preferences → Windows Registry write
- `Get-GPOReport -Name <name> -ReportType XML` — used to resolve registry key/value/type
- `New-GPO`, `Get-GPO`

---

## Code Conventions

### All Functions

- Use `[CmdletBinding()]` on every function
- Public functions: `[CmdletBinding(SupportsShouldProcess)]`; import functions add `ConfirmImpact='High'`
- Every function's `begin` block calls `Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState`
- Follow the template in `src/templates/PlainPublicFunction.tem`
- Use `Write-Verbose` for informational messages, `Write-Warning` for non-terminating issues,
  `Write-Error -ErrorAction Stop` or `throw` for terminating errors
- No aliases; full cmdlet/parameter names throughout (PSScriptAnalyzer enforced)

### Approved Verbs

Use only PowerShell-approved verbs. Run `Get-Verb` if unsure.

### Module-Scoped State (defined in PreLoad.ps1)

```powershell
$script:AdminTemplateAreas      # @('Registry')
$script:PreferenceAreas         # all GP Preference types
$script:AllSupportedAreas       # concatenation of above two
$script:RegistryTypeMap         # string -> [Microsoft.Win32.RegistryValueKind]
$script:PreferenceSYSVOLMap     # SDM area name -> SYSVOL Preferences subfolder name
$script:PreferenceXmlFileMap    # SDM area name -> Preferences XML filename
$script:GPOReportCache          # @{} — GUID-keyed cache of Get-GPOReport XML results
$script:OfficeIMOLoaded         # $true after OfficeIMO plugin loads successfully
```

### Private Function Responsibilities

| Function | Responsibility |
|---|---|
| `Get-CallerPreference` | Propagates -Verbose/-Debug from caller into function scope |
| `Test-ModuleDependency` | Validates GroupPolicy RSAT, SDM-GPMC module, OfficeIMO assembly |
| `ConvertFrom-SDMSettingPath` | Parses pipe-delimited SDM SettingPath; filters out-of-scope categories |
| `Resolve-RegistryMapping` | Extracts RegistryKey/ValueName/ValueType from Get-GPOReport XML; caches by GUID |
| `ConvertTo-GPPreferenceXml` | Generates SYSVOL-compatible XML for each Preference type |
| `Format-GPOExcelWorkbook` | Creates OfficeIMO workbook with per-GPO table sheets + TOC |
| `Import-RegistryPolicySetting` | Applies one Admin Template row via Set-GPRegistryValue |
| `Import-PreferencePolicySetting` | Routes Preference rows to Set-GPPrefRegistryValue or XML write |
| `Update-GPOVersion` | Writes Preference XML to SYSVOL + bumps gpt.ini; DA check + local fallback |

### SYSVOL Write Safety

`Update-GPOVersion` always checks Domain Admin membership via
`[System.Security.Principal.WindowsIdentity]::GetCurrent().Groups` for SID suffix `-512`.

- **Domain Admin:** Writes to `\\<domain>\SYSVOL\<domain>\Policies\{GUID}\<Scope>\Preferences\<Folder>\`
  then updates `gpt.ini` version counter.
- **Not Domain Admin:** Writes to `<LocalFallbackPath>\SYSVOL_Staging\{GUID}\...` and emits
  `Write-Warning` with exact SYSVOL target path for manual copy by an administrator.

### File Schema

CSV/Excel columns in order:
`GPOName`, `GPOGuid`, `Domain`, `Scope`, `Category`, `PolicyPath`, `SettingName`,
`Value`, `ValueType`, `RegistryKey`, `RegistryValueName`, `State`

---

## File Layout

```text
src/
  public/          # Exported functions (4): Export-GPOSetting, Import-GPOSetting,
                   #   New-GPOMigrationTemplate, Compare-GPOSetting
  private/         # Helper functions (9 total including Get-CallerPreference)
  other/
    PreLoad.ps1    # Module-scoped constants — edit here for new constants/maps
    PostLoad.ps1   # Plugin loader — do not edit unless adding a new plugin type
  templates/
    PlainPublicFunction.tem   # Template for new public functions

plugins/
  sdm-gpmc/        # SDM-GPMC plugin (already set up by maintainer)
  OfficeIMO/       # OfficeIMO.Excel plugin — lib/*.dll loaded via Assembly.LoadFrom

tests/
  shared/
    TestHelpers.psm1    # Shared mock generators and utilities for Pester 5
  unit/
    private/            # One .Tests.ps1 per private function
    public/             # One .Tests.ps1 per public function
  intergration/
    public/             # Real AD environment tests; tagged IntegrationTest
  meta/
    Meta.tests.ps1      # Module health checks (Pester 5)

reference/         # Reference materials only — NOT loaded at runtime
  Microsoft.GroupPolicy.Management.dll
  Windows11PolicySettings25H2.xlsx

docs/
  ImplementationPlan.md   # Full implementation plan with status tracking
  Acknowledgements.md     # Third-party credits
```

---

## Testing Guidelines

- Use **Pester 5** syntax: `Should -Be`, `Should -Invoke`, `BeforeAll`, `AfterAll`, `BeforeEach`
- Import the module under test in `BeforeAll { Import-Module $ModulePath -Force }`;
  clean up in `AfterAll { Remove-Module GPOMigration }`
- Mock all external commands (`Out-SDMGPSettings`, `Get-GPOReport`, `Set-GPRegistryValue`,
  `New-GPO`, etc.) and files — unit tests must not require an AD connection or real data
- Integration tests use `It '...' -Tag 'IntegrationTest'` so they are excluded from
  `Invoke-Pester` runs that omit `-Tag IntegrationTest`
- Test `Update-GPOVersion` Domain Admin paths by mocking
  `[System.Security.Principal.WindowsIdentity]::GetCurrent()`
- Do NOT disable tests or suppress PSScriptAnalyzer rules without a documented reason in an inline
  comment, and NEVER use `-skip` or remove tests just to gain a passing result

---

## Build System

- `.\Build.ps1 -BuildModule` — compiles module
- `.\Build.ps1 -Test` — runs meta + unit tests
- `.\Build.ps1 -TestBuildAndInstallModule` — full pipeline
- `.\Build.ps1 -AddMissingCBH` — inserts missing comment-based help

PSScriptAnalyzer rules are in `PSScriptAnalyzerSettings.psd1`. Do not suppress rules without a
documented reason in an inline comment.

---

## What NOT to Do

- Do not add features beyond the stated scope (no Windows Settings, no SID translation,
  no GPO link management)
- Do not add a graceful "if OfficeIMO is missing" fallback — it is always bundled
- Do not load anything from `reference/` at runtime — that folder is documentation only
- Do not modify `PostLoad.ps1` unless adding a new plugin category
- Do not use `Import-Module` for GroupPolicy inside functions — it loads via RequiredModules
- Do not create helpers for one-time operations; prefer inline logic for narrow tasks
- Do not add docstrings or comments to code you did not change
- Do not disable tests or PSScriptAnalyzer rules without a documented reason in an inline comment
- Do not use `-skip` or remove tests just to get a passing build
