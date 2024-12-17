#Requires -Version 5.1
<#
.SYNOPSIS
    Launch Windows Sandbox with a configuration built from the user's intent.

.DESCRIPTION
    -None-

.PARAMETER TargetPath
    An item to launch into the container. This could be a file or directory.
    The script will automatically figure out what to do with this item.

.EXAMPLE
     Start-Container -TargetPath 'C:\Windows\System32\notepad.exe'

.EXAMPLE
     Start-Container -TargetPath 'C:\Users\Public\Desktop'

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
    [Parameter(Mandatory = $true)]
    [ValidateScript({
            if (-Not ($_ | Test-Path) ) {
                throw "Item does not exist."
            }
            if ((-Not [System.IO.Directory]::Exists($_)) -and (-Not [System.IO.File]::Exists($_))) {
                throw "The TargetPath argument is an unexpected item, only files and directories are supported."
            }
            return $true
        })]
    [string]$TargetPath
)

# WARN; Variable types are sticky, so we manually override the type once
[System.Management.Automation.PathInfo]$TargetPath = Resolve-Path $TargetPath
$ConfigurationPath = New-TemporaryFile
$SandboxBasePath = "C:\Users\WDAGUtilityAccount\Desktop"

$ItemPreparation = 'folder'
$SandboxMounts = @()
$LogonCommand = ''

$IsFile = [System.IO.File]::Exists($TargetPath)
if ($IsFile) {
    $ItemPreparation = (Get-Item $TargetPath).Extension

    $ParentDirectoryPath = (Get-Item $TargetPath).Directory
    $SandboxMounts += @{
        HostPath      = $ParentDirectoryPath
        ContainerPath = $SandboxBasePath, (Get-Item $ParentDirectoryPath).Name -join '\'
    }
}
else {
    $SandboxMounts += @{
        HostPath      = $TargetPath
        ContainerPath = $SandboxBasePath, (Get-Item $TargetPath).Name -join '\'
    }
}

function Get-Incantation {
    param(
        # Program to launch within the container
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        $Process,

        # Arguments for the started process
        # This parameter is forwarded to ArgumentList of Start-Process
        # NOTE; We do the quoting for you!
        [Parameter(Position = 1)]
        [string[]]
        $ArgumentList,

        # Toggle flag to produce a command window with (hopefully) error messages
        [Parameter()]
        [switch]
        $VisiblePrompt
    )

    function FlattenArgumentList {
        param([Parameter(Mandatory = $true, Position = 0)][string[]] $arguments)
        # ERROR; Handle nested quoting properly! For each level deep we need to escape quotes
        ($arguments | ForEach-Object { $_ -replace "'", "''" } | ForEach-Object { "'$_'" }) -join ', '
    }

    if ($VisiblePrompt.IsPresent) {
        # The launcher process has a flag to hide the console window => any directly invoked script
        # will not be visible (but would run!) unless we invoke a new command window
        $ArgumentList = FlattenArgumentList $ArgumentList
        $ArgumentList = @('-NoExit', 'Start-Process', "$Process @($ArgumentList)")
        $Process = 'powershell'
    }

    $ArgumentList = FlattenArgumentList $ArgumentList
    # "[..] -command "Start-Process powershell @('-NoExit', 'Start-Process', 'powershell @(''-NoExit'')')"
    "powershell -executionpolicy unrestricted -command ""Start-Process $Process @($ArgumentList)"""
}

switch ($ItemPreparation) {
    "folder" {
        $ContainerFilePath = $SandboxBasePath, (Get-Item $TargetPath).Name -join '\'
        $LogonCommand = Get-Incantation 'explorer.exe' $ContainerFilePath
    }
    ".msi" {
        $ContainerFilePath = $SandboxMounts[0].ContainerPath, (Get-Item $TargetPath).Name -join '\'
        $LogonCommand = Get-Incantation 'msiexec.exe' @('/i', $ContainerFilePath)
    }
    { $_ -in ".cmd", ".bat" } {
        $ContainerFilePath = $SandboxMounts[0].ContainerPath, (Get-Item $TargetPath).Name -join '\'
        $LogonCommand = Get-Incantation 'cmd.exe' @('/k', $ContainerFilePath)
    }
    ".ps1" {
        $ContainerFilePath = $SandboxMounts[0].ContainerPath, (Get-Item $TargetPath).Name -join '\'
        $LogonCommand = Get-Incantation 'powershell.exe' @('-ExecutionPolicy Bypass', '-NoExit', '-File', $ContainerFilePath)
    }
    Default {
        # Default behavious is shell-executable thingie (file-like with default app association)
        $ContainerFilePath = $SandboxMounts[0].ContainerPath, (Get-Item $TargetPath).Name -join '\'
        $LogonCommand = Get-Incantation 'explorer.exe' $ContainerFilePath
    }
}

@"
<Configuration>
    <VGpu>disable</VGpu>
    <Networking>enable</Networking>
    <AudioInput>disable</AudioInput>
    <VideoInput>disable</VideoInput>
    <ProtectedClient>enable</ProtectedClient>
    <PrinterRedirection>disable</PrinterRedirection>
    <ClipboardRedirection>enable</ClipboardRedirection>
    <ClipboardRedirection>disable</ClipboardRedirection>
    <!--
        Node text cannot be empty otherwise a startup exception is thrown.
        Remove node for automatic memory calculation, or set a value larger than 1500.
        WARN; A value lower than 1.5GB will cause performance degradation due to swapping.
    -->
    <MemoryInMB>2700</MemoryInMB>
    <MappedFolders>
        $(
            $SandboxMounts | ForEach-Object {
                @"
                <MappedFolder>
                    <HostFolder>$($_.HostPath)</HostFolder>
                    <SandboxFolder>$($_.ContainerPath)</SandboxFolder>
                    <ReadOnly>true</ReadOnly>
                </MappedFolder>
"@
            }
        )
    </MappedFolders>
    <LogonCommand>
        <Command><![CDATA[$($LogonCommand)]]></Command>
    </LogonCommand>
</Configuration>
"@ | Out-File $ConfigurationPath -Encoding utf8

# Windows sandbox tool _requires_ the configuration file ending on wsb extension
Move-Item -Path $ConfigurationPath -Destination "$ConfigurationPath.wsb"

# Launch the sandbox providing our situational configuration file
& "$env:SystemRoot\System32\WindowsSandbox.exe" "$ConfigurationPath.wsb"
