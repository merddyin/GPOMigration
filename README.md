# GPOMigration

Exports and Imports GPO settings and values to-from a CSV file.

## Description

Exports and Imports GPO settings and values to-from a CSV file.

## Introduction

## Requirements

## Installation

Manual Installation
`iex (New-Object Net.WebClient).DownloadString("https://github.com/merddyin/GPOMigration/raw/master/Install.ps1")`

Alternatively, you can access the releases at the right side of this page to download the file manually. This module has NOT been published to the gallery.

## Features

- Exports ADMX and registry-based prefernces to Excel (or CSV)
- Accepts an Excel file (or CSV) with the correct formatting and creates a new GPO with the indicated settings
- Compare settings and values between two exported GPO collections
- Create a new template file to build out desired settings from scratch

Note: Module is not capable of exporting or processing custom ADMX templates, nor does it capture anything not based on a registry value. Exporting and importing of policy preferences is best effort and requires access to write to the SYSVOL.

## Versions

0.0.1 - Initial Release (Alpha)

## Contribute

Please feel free to contribute by opening new issues or providing pull requests.
For the best development experience, open this project as a folder in Visual
Studio Code and ensure that the PowerShell extension is installed.

* [Visual Studio Code](https://code.visualstudio.com/)
* [PowerShell Extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode.PowerShell)

This module is tested with the PowerShell testing framework Pester. To run all tests, just start the included build scrip with the test param `.\Build.ps1 -test`.

## Other Information

**Author:** Topher Whitfield

**Website:** https://github.com/merddyin/GPOMigration
