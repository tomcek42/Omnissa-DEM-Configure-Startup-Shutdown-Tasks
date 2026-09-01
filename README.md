# Omnissa DEM - Configure Startup/Shutdown Tasks

PowerShell script that configures the **Local Group Policy** of a Windows machine so that
Omnissa DEM (Dynamic Environment Manager) executes its *Computer Environment*
Startup and Shutdown Tasks.

Doing this by hand means clicking through `gpedit.msc` on every machine (or every golden
image). This script writes the same settings directly to `Registry.pol`, the Group Policy
registry hive and `scripts.ini`, so it can be run unattended — for example during image
creation or via a deployment tool.

## What it does

1. **Disables** `Computer Configuration > Administrative Templates > System > Scripts >
   Run startup scripts asynchronously` — startup scripts then run **synchronously**, which
   DEM requires so that its startup tasks finish before the user logon continues.
2. Registers `FlexEngine.exe` as a local **startup script** with the parameter
   `-StartupTasks` and as a **shutdown script** with `-ShutdownTasks`
   (`Computer Configuration > Windows Settings > Scripts (Startup/Shutdown)`).
3. Creates `%SystemRoot%\System32\GroupPolicy\Machine\Scripts\scripts.ini` so the entries
   are also visible in the `gpedit.msc` GUI.
4. Removes stale `RunComputerPSScriptsFirst` / `RunPSScriptsFirst` values from
   `Registry.pol` and runs `gpupdate /force`.

## Requirements

- Windows with the Local Group Policy Editor (Pro / Enterprise / Server)
- An elevated PowerShell session (`#Requires -RunAsAdministrator`)
- Omnissa DEM FlexEngine installed at `C:\Program Files\Omnissa\DEM\FlexEngine.exe`
- The [`PolicyFileEditor`](https://www.powershellgallery.com/packages/PolicyFileEditor)
  module — installed automatically from the PowerShell Gallery if missing

## Usage

### One-liner

Run this in an **elevated** PowerShell session:

```powershell
irm https://raw.githubusercontent.com/tomcek42/Omnissa-DEM-Configure-Startup-Shutdown-Tasks/main/DEM_Configure_Startup_Shutdown_Tasks.ps1 | iex
```

To pin a released version instead of `main`, replace the branch with a tag:

```powershell
irm https://raw.githubusercontent.com/tomcek42/Omnissa-DEM-Configure-Startup-Shutdown-Tasks/v1.0.0/DEM_Configure_Startup_Shutdown_Tasks.ps1 | iex
```

### Local file

```powershell
# Run in an elevated PowerShell session
.\DEM_Configure_Startup_Shutdown_Tasks.ps1
```

A **reboot is required** for the policies to take effect.

## Customising

If DEM is installed elsewhere, adjust the path near the top of Part 2:

```powershell
$flexEnginePath = "C:\Program Files\Omnissa\DEM\FlexEngine.exe"
```

## Verification

Open `gpedit.msc` and check:

- `Computer Configuration > Administrative Templates > System > Scripts`
  → *Run startup scripts asynchronously* = **Disabled**
- `Computer Configuration > Windows Settings > Scripts (Startup/Shutdown)`
  → Startup: `FlexEngine.exe -StartupTasks`
  → Shutdown: `FlexEngine.exe -ShutdownTasks`

## Notes

- The script writes to the **local** policy. In a domain, an equivalent GPO is usually the
  better choice — this is aimed at golden images, non-domain machines and standalone hosts.
- Existing local startup/shutdown script entries with index `0` are overwritten.

## Licence

MIT
