# OfficeIMO Plugin — UnLoad.ps1
# Called by PostLoad.ps1 when the GPOMigration module is removed.
# Assembly.LoadFrom loads into the default AssemblyLoadContext, which persists for the
# lifetime of the PowerShell session. There is no safe way to unload individual assemblies
# from the default context, so this script is intentionally a no-op.
#
# If DLL isolation becomes a requirement in a future version, migrate Load.ps1 to use
# an isolated System.Runtime.Loader.AssemblyLoadContext and call $alc.Unload() here.

$script:OfficeIMOLoaded = $false
Write-Verbose "OfficeIMO plugin unloaded."
