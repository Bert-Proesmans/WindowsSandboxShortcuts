# Windows Sandbox Shortcuts

Easily open files and directories within the Windows Sandbox system.

This tool creates custom configuration scripts based on the user's intent. The
following file extensions are accomodated;

* v1.1
    * pdf
    * ps1
    * cmd/bat
* v1.0
    * Directory
    * exe
    * msi

## Getting started

A prerequisite is the Windows Optional Feature 'Containers-DisposableClientVM',
you can install that by running the following command in an elevated powershell
prompt;

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM
```

### Installation

1. Clone this repository
2. Create an empty directory accessible for all users, eg `C:\Program Files\WindowsSandbox`
3. Open an elevated powershell command prompt
4. Change directory to the cloned repository on your local system
4. Execute the `Install-Shortcuts.ps1` script
    * `powershell.exe -ExecutionPolicy ByPass -File .\Install-Shortcuts.ps1 -InstallDirectory 'C:\Program Files\WindowsSandbox'`

You can uninstall with the script 'Uninstall-Shortcuts.ps1'.
