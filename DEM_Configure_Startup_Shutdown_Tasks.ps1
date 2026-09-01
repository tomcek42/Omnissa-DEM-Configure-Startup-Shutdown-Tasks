# ============================================================
# PowerShell Script to configure Local Policy for
# Omnissa DEM Computer Environment Startup/Shutdown Tasks
# ============================================================
#Requires -RunAsAdministrator

# Explicit elevation check: #Requires is ignored when the script is piped into
# Invoke-Expression (the 'irm ... | iex' one-liner), so verify it ourselves.
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'This script must be run from an elevated PowerShell session (Run as Administrator).'
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Configuring Local Policy for Omnissa DEM Startup/Shutdown Tasks" -ForegroundColor Cyan
Write-Host "============================================================`n" -ForegroundColor Cyan

# --- Install PolicyFileEditor Module if not present ---
if (-not (Get-Module -ListAvailable -Name PolicyFileEditor)) {
    Write-Host "PolicyFileEditor module not found. Installing..." -ForegroundColor Yellow
    Install-Module -Name PolicyFileEditor -Force -Scope CurrentUser
    Write-Host "  [OK] PolicyFileEditor module installed.`n" -ForegroundColor Green
} else {
    Write-Host "  [OK] PolicyFileEditor module already available.`n" -ForegroundColor Green
}

Import-Module PolicyFileEditor

# ============================================================
# PART 1: Disable "Run startup scripts asynchronously"
# Computer Configuration > Administrative Templates > System > Scripts
# Disabling this policy = Startup scripts run synchronously
# ============================================================

$machinePolPath = "$env:SystemRoot\System32\GroupPolicy\Machine\Registry.pol"

$polDir = Split-Path -Path $machinePolPath -Parent
if (-not (Test-Path $polDir)) {
    New-Item -Path $polDir -ItemType Directory -Force | Out-Null
}

# "Run startup scripts asynchronously" = Disabled
# Registry: RunStartupScriptSync = 1 means synchronous (= async disabled)
Set-PolicyFileEntry -Path $machinePolPath `
    -Key 'Software\Microsoft\Windows\CurrentVersion\Policies\System' `
    -ValueName 'RunStartupScriptSync' `
    -Data 1 `
    -Type DWord
Write-Host "  [OK] Disabled 'Run startup scripts asynchronously'" -ForegroundColor Green

# ============================================================
# PART 2: Configure Startup and Shutdown Scripts
# Computer Configuration > Windows Settings > Scripts (Startup/Shutdown)
# Script: C:\Program Files\Omnissa\DEM\FlexEngine.exe
# Startup Parameter: -StartupTasks
# Shutdown Parameter: -ShutdownTasks
# ============================================================

Write-Host "`nConfiguring Startup/Shutdown scripts..." -ForegroundColor Cyan

$flexEnginePath = "C:\Program Files\Omnissa\DEM\FlexEngine.exe"

# --- Registry: Startup Script ---
$startupPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\0"
)

foreach ($path in $startupPaths) {
    if (-not (Test-Path $path)) {
        New-Item -Path $path -Force | Out-Null
    }
    Set-ItemProperty -Path $path -Name "GPO-ID" -Value "LocalGPO" -Type String
    Set-ItemProperty -Path $path -Name "SOM-ID" -Value "Local" -Type String
    Set-ItemProperty -Path $path -Name "FileSysPath" -Value "$env:SystemRoot\System32\GroupPolicy\Machine" -Type String
    Set-ItemProperty -Path $path -Name "DisplayName" -Value "Local Group Policy" -Type String
    Set-ItemProperty -Path $path -Name "GPOName" -Value "Local Group Policy" -Type String
    Set-ItemProperty -Path $path -Name "PSScriptOrder" -Value 1 -Type DWord

    $scriptEntryPath = "$path\0"
    if (-not (Test-Path $scriptEntryPath)) {
        New-Item -Path $scriptEntryPath -Force | Out-Null
    }
    Set-ItemProperty -Path $scriptEntryPath -Name "Script" -Value $flexEnginePath -Type String
    Set-ItemProperty -Path $scriptEntryPath -Name "Parameters" -Value "-StartupTasks" -Type String
    Set-ItemProperty -Path $scriptEntryPath -Name "IsPowershell" -Value 0 -Type DWord
    Set-ItemProperty -Path $scriptEntryPath -Name "ExecTime" -Value ([byte[]](0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)) -Type Binary
}
Write-Host "  [OK] Startup script: $flexEnginePath -StartupTasks" -ForegroundColor Green

# --- Registry: Shutdown Script ---
$shutdownPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Shutdown\0",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Shutdown\0"
)

foreach ($path in $shutdownPaths) {
    if (-not (Test-Path $path)) {
        New-Item -Path $path -Force | Out-Null
    }
    Set-ItemProperty -Path $path -Name "GPO-ID" -Value "LocalGPO" -Type String
    Set-ItemProperty -Path $path -Name "SOM-ID" -Value "Local" -Type String
    Set-ItemProperty -Path $path -Name "FileSysPath" -Value "$env:SystemRoot\System32\GroupPolicy\Machine" -Type String
    Set-ItemProperty -Path $path -Name "DisplayName" -Value "Local Group Policy" -Type String
    Set-ItemProperty -Path $path -Name "GPOName" -Value "Local Group Policy" -Type String
    Set-ItemProperty -Path $path -Name "PSScriptOrder" -Value 1 -Type DWord

    $scriptEntryPath = "$path\0"
    if (-not (Test-Path $scriptEntryPath)) {
        New-Item -Path $scriptEntryPath -Force | Out-Null
    }
    Set-ItemProperty -Path $scriptEntryPath -Name "Script" -Value $flexEnginePath -Type String
    Set-ItemProperty -Path $scriptEntryPath -Name "Parameters" -Value "-ShutdownTasks" -Type String
    Set-ItemProperty -Path $scriptEntryPath -Name "IsPowershell" -Value 0 -Type DWord
    Set-ItemProperty -Path $scriptEntryPath -Name "ExecTime" -Value ([byte[]](0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)) -Type Binary
}
Write-Host "  [OK] Shutdown script: $flexEnginePath -ShutdownTasks" -ForegroundColor Green

# --- Create scripts.ini (required for gpedit.msc display) ---
$scriptsIniPath = "$env:SystemRoot\System32\GroupPolicy\Machine\Scripts\scripts.ini"
$scriptsDir = Split-Path -Path $scriptsIniPath -Parent

if (-not (Test-Path $scriptsDir)) {
    New-Item -Path $scriptsDir -ItemType Directory -Force | Out-Null
}

$scriptsIniContent = @"
[Startup]
0CmdLine=$flexEnginePath
0Parameters=-StartupTasks

[Shutdown]
0CmdLine=$flexEnginePath
0Parameters=-ShutdownTasks
"@

Set-Content -Path $scriptsIniPath -Value $scriptsIniContent -Encoding Unicode
Write-Host "  [OK] scripts.ini created" -ForegroundColor Green

# --- Remove stale entries from Registry.pol if present ---
$staleValues = @('RunComputerPSScriptsFirst', 'RunPSScriptsFirst')
foreach ($valueName in $staleValues) {
    try {
        Remove-PolicyFileEntry -Path $machinePolPath `
            -Key 'Software\Microsoft\Windows\CurrentVersion\Policies\System' `
            -ValueName $valueName -ErrorAction SilentlyContinue
    } catch {}
}

# --- Force Group Policy Update ---
Write-Host "`nForcing Group Policy update..." -ForegroundColor Yellow
gpupdate /force

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "Configuration complete!" -ForegroundColor Green
Write-Host "Verify in gpedit.msc:" -ForegroundColor Yellow
Write-Host "  1. Computer Configuration > Administrative Templates > System > Scripts" -ForegroundColor White
Write-Host "     -> 'Run startup scripts asynchronously' = Disabled" -ForegroundColor White
Write-Host "  2. Computer Configuration > Windows Settings > Scripts (Startup/Shutdown)" -ForegroundColor White
Write-Host "     -> Startup:  FlexEngine.exe -StartupTasks" -ForegroundColor White
Write-Host "     -> Shutdown: FlexEngine.exe -ShutdownTasks" -ForegroundColor White
Write-Host "A restart is required for the policies to take effect." -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan
