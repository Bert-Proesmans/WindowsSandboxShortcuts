#Requires -Version 5.1
<#
.SYNOPSIS
    Install context menu items in SHELL to quickly open items in a Windows Sandbox.

.DESCRIPTION
    -None-

.PARAMETER InstallDirectory
    An existing directory where this script can copy its runtime dependencies into.

.PARAMETER DarkModeIcon
    Add a white icon to the context menu items that launch the containers. 

.EXAMPLE
     Install-Shortcuts

.EXAMPLE
     Install-Shortcuts -InstallDirectory 'C:\Program Files\OpenInContainer' -DarkModeIcon

.LINK
    https://github.com/Bert-Proesmans/WindowsSandboxShortcuts

.LINK
    More information about Windows Sandbox can be found here;
    https://learn.microsoft.com/en-us/windows/security/application-security/application-isolation/windows-sandbox/windows-sandbox-overview

.COMPONENT
    This script requires Windows Optional Feature 'Containers-DisposableClientVM'

.NOTES
    Author:  Bert Proesmans

    Install the required Windows Optional Feature 'Containers-DisposableClientVM' by
    executing the following command in an elevated powershell prompt;
    `Enable-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM`
#>

param (
    [ValidateScript({
            if (-Not ($_ | Test-Path) ) {
                throw "Folder does not exist."
            }
            if (-Not ($_ | Test-Path -PathType Container) ) {
                throw "The InstallDirectory argument must be a directory. File paths are not allowed."
            }
            return $true
        })]
    [string]$InstallDirectory = '.', # Current working directory
    [switch]$DarkModeIcon
)

# WARN; Variable types are sticky, so we manually override the type once
[System.Management.Automation.PathInfo]$InstallDirectory = Resolve-Path $InstallDirectory
$SandboxIconPath = '%SystemRoot%\System32\WindowsSandbox.exe'
if ($DarkModeIcon.IsPresent) {
    $SandboxIconPath = '%SystemRoot%\System32\WindowsSandbox.exe,1'
}
$BootstrapScriptPath = $InstallDirectory | Join-Path -ChildPath 'Start-Container.ps1'

$ParentPath = Resolve-Path $PSScriptRoot
if ($ParentPath.Path -ne $InstallDirectory.Path) {
    $FilesToCopy = @(
        $ParentPath | Join-Path -ChildPath 'Start-Container.ps1'
    )

    Copy-Item -Path $FilesToCopy -Destination $InstallDirectory -Force | Out-Null
}

# NOTE; The default powershell interpreter is called directly. If a different powershell is required;
#   * 'Get-Command powershell).Definition' to use powershell on install user's PATH
#   * 'powershell.exe' to use the powershell on runtime user's PATH
#$PowershellPath = (Get-Command powershell).Definition
$PowershellPath = "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
$CommandScript = @(
    # ERROR; Command line is parsed by command processor so grouping words requires double quotes (")!
    # Single quotes (') would be seen as a literal, not a grouping indicator.
    """$PowershellPath"""
    , '-NoProfile'
    , '-ExecutionPolicy ByPass'
    , "-File ""$BootstrapScriptPath"""
    , "-TargetPath ""%V"""
)

Function New-QuickItem {
    param (
        $FileCommonName,
        $FileExtension,
        $ItemLabel = "Run $FileExtension in a sandbox",
        [string[]]$CustomPath = @()
    )

    $ClassesPath = (@("Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Classes", $FileCommonName) + $CustomPath) -join '\'
    $QuickItemPath = $ClassesPath, 'Shell', $ItemLabel -join '\'
    $QuickItemCommandPath = $QuickItemPath, 'Command' -join '\'
    # New-Item -Path $QuickItemPath -Force
    New-Item -Path $QuickItemCommandPath -Force | Out-Null

    $Properties = @(
        @{
            Path         = $QuickItemPath
            Name         = 'icon'
            PropertyType = 'String'
            Value        = $script:SandboxIconPath
        }
        @{
            Path         = $QuickItemCommandPath
            Name         = '(Default)'
            PropertyType = 'ExpandString'
            Value        = "$($script:CommandScript)"
        }
    )

    $Properties | ForEach-Object -Process { New-ItemProperty @_ -Force } | Out-Null
}


# ProgID items, which depend on installed software state
# The filetypes are from windows core, so we can composite our config into the registry safely
New-QuickItem -FileCommonName 'Directory' -ItemLabel "Open folder in a sandbox"
New-QuickItem -FileCommonName 'Directory' -CustomPath "Background" -ItemLabel "Open folder in a sandbox"
New-QuickItem -FileCommonName 'exefile' -FileExtension 'EXE'
New-QuickItem -FileCommonName 'Msi.Package' -FileExtension 'MSI'

# Stable file associations independent of software state
# REF; https://learn.microsoft.com/en-us/windows/win32/shell/app-registration#registering-verbs-and-other-file-association-information
New-QuickItem -CustomPath 'SystemFileAssociations', '.pdf' -FileExtension 'PDF'
New-QuickItem -CustomPath 'SystemFileAssociations', '.ps1' -ItemLabel "Open script in a sandbox"
New-QuickItem -CustomPath 'SystemFileAssociations', '.cmd' -ItemLabel "Open script in a sandbox"
New-QuickItem -CustomPath 'SystemFileAssociations', '.bat' -ItemLabel "Open script in a sandbox"
# TODO; REG ..
