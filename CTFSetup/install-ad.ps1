# Path to script 3
$ScriptPath = "C:\CTFSetup\network_config.ps1"

#Create relative path for next script
$NetworkConfig = Join-Path -Path $PSScriptRoot -ChildPath "network_config.ps1"
Write-Host "`n Network Config Script path: $NetworkConfig"

#Set at logon
$CurrentUser = "$env:USERNAME"

#Create scheduled task to run network_config.ps1
if (-not (Get-ScheduledTask -TaskName "NetworkConfig" -ErrorAction SilentlyContinue)) {
    try {
        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File `"$NetworkConfig`""
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $CurrentUser
        Register-ScheduledTask -TaskName "NetworkConfig" -Action $action -Trigger $trigger

        Write-Host "`nScheduled Task 'NetworkConfig' created successfully!"
    } catch {
        Write-Error "`nFailed to create 'NetworkConfig' task: $_"
    }
} else {
    Write-Host "`nScheduled Task 'NetworkConfig' already exists."
}

Pause

# Install AD Domain Services role
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

Import-Module ADDSDeployment

# DSRM password
$DSRMPassword = ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force

# Install new forest
Install-ADDSForest `
    -DomainName "localnet.ctf" `
    -DomainNetbiosName "LOCALNET" `
    -SafeModeAdministratorPassword $DSRMPassword `
    -InstallDNS `
    -Force

Unregister-ScheduledTask -TaskName "InstallAD" -Confirm:$false
Write-Host "Install-AD Task has been unregistered."
Pause