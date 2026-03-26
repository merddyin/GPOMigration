# GPOMigration Change Log

Project Site: [https://github.com/merddyin/GPOMigration](https://github.com/merddyin/GPOMigration)

## Version 0.1.0
- Replaced the InvokeBuild-based process with a native PowerShell build and release pipeline in Build.ps1.
- Added deterministic release packaging to produce `release/GPOMigration/<version>` and a zip artifact.
- Added optional PSGallery packaging support that creates a local `.nupkg` artifact and can publish with an API key.
- Updated module manifest exports to explicit public function names.
- Refreshed project documentation and added per-function markdown help pages.

## Version 0.0.1
- Initial release
