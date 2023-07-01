#Requires -Version 5.1
<#
.SYNOPSIS
    Removes all sandbox-related configuration and files from the installation folder.

.DESCRIPTION
    -None-

.PARAMETER InstallDirectory
    An existing directory where this script should remove its runtime dependencies from.

.EXAMPLE
     Uninstall-Shortcuts -InstallDirectory 'C:\Program Files\OpenInContainer'

.LINK
    https://github.com/Bert-Proesmans/WindowsSandboxShortcuts

.NOTES
    Author:  Bert Proesmans
#>

param (
    [Parameter(Mandatory = $true)]
    [ValidateScript({
            if (-Not ($_ | Test-Path) ) {
                throw "Folder does not exist."
            }
            if (-Not ($_ | Test-Path -PathType Container) ) {
                throw "The InstallDirectory argument must be a directory. File paths are not allowed."
            }
            return $true
        })]
    [string]$InstallDirectory
)
# WARN; Variable types are sticky, so we manually override the type once
[System.Management.Automation.PathInfo]$InstallDirectory = Resolve-Path $InstallDirectory
$FilesToRemove = @(
    $InstallDirectory | Join-Path -ChildPath 'Start-Container.ps1'
)
Remove-Item -Path $FilesToRemove -Force | Out-Null

Function Remove-QuickItem {
    param (
        $FileCommonName,
        $FileExtension,
        $ItemLabel = "Run $FileExtension in a sandbox",
        [string[]]$CustomPath = @()
    )

    $ClassesPath = (@("Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Classes", $FileCommonName) + $CustomPath) -join '\'
    $QuickItemPath = $ClassesPath, 'Shell', $ItemLabel -join '\'
    Remove-Item -Path $QuickItemPath -Recurse -Force | Out-Null
}


Remove-QuickItem -FileCommonName 'Directory' -ItemLabel "Open folder in a sandbox"
Remove-QuickItem -FileCommonName 'Directory' -CustomPath "Background" -ItemLabel "Open folder in a sandbox"
Remove-QuickItem -FileCommonName 'exefile' -FileExtension 'EXE'
Remove-QuickItem -FileCommonName 'Msi.Package' -FileExtension 'MSI'