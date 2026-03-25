
# CTF Lab Setup Script
# Windows Server 2022

Set-ExecutionPolicy Bypass -Scope LocalMachine -Force

# Variables
$SharePath = "C:\CTFShare"
$ShareName = "CTFShare"

# Create Shared Folder

New-Item -ItemType Directory -Path $SharePath -Force

# Set NTFS permissions
$acl = Get-Acl $SharePath
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "Everyone",
    "ReadAndExecute",
    "ContainerInherit,ObjectInherit",
    "None",
    "Allow"
)
$acl.AddAccessRule($rule)
Set-Acl $SharePath $acl

# Create SMB Share
New-SmbShare `
    -Name $ShareName `
    -Path $SharePath `
    -ReadAccess "Everyone"

# SMB Configuration (CTF Mode)
# Represents weakening of OS/Attack Surface, do not use in live environments

# Allow insecure guest logons
Set-ItemProperty `
    -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" `
    -Name "AllowInsecureGuestAuth" `
    -Value 1 `
    -Force

# Ensure SMB is enabled
Set-SmbServerConfiguration `
    -EnableSMB2Protocol $true `
    -Force

# Enable plaintext password support
Set-ItemProperty `
    -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" `
    -Name "EnablePlainTextPassword" `
    -Value 1 `
    -Force

# Restart SMB Service

Restart-Service LanmanServer -Force

# Base Configs

#enable fw rules for ping
Enable-NetFirewallRule -Name FPS-ICMP4-ERQ-In

#set time zone
tzutil /s "Central Standard Time"

#Create relative path for Desktop Image
$DesktopPath = Join-Path -Path $PSScriptRoot -ChildPath "bkgrd.png"
Write-Host "Setting desktop image to $DesktopPath"

#Change Desktop Image
Set-ItemProperty `
    -path 'HKCU:\Control Panel\Desktop\' `
    -name wallpaper `
    -value $DesktopPath

#rename
Rename-Computer -NewName "LNDC" -Force

#Create relative path for next script
$InstallAD = Join-Path -Path $PSScriptRoot -ChildPath "install-ad.ps1"
Write-Host "`n Install AD Script path: $InstallAD"

#Set at logon
$CurrentUser = "$env:USERNAME"

#Create scheduled task to run install-ad.ps1
if (-not (Get-ScheduledTask -TaskName "InstallAD" -ErrorAction SilentlyContinue)) {
    try {
        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File `"$InstallAD`""
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $CurrentUser
        Register-ScheduledTask -TaskName "InstallAD" -Action $action -Trigger $trigger

        Write-Host "`nScheduled Task 'InstallAD' created successfully!"
    } catch {
        Write-Error "`nFailed to create 'InstallAD' task: $_"
    }
} else {
    Write-Host "`nScheduled Task 'InstallAD' already exists."
}

Pause

# Reboot to start AD installation
Restart-Computer -Force