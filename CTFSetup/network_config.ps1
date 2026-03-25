#network_config.ps1

# Variables
$AdminUser = "svc_admin"
$AdminPassword = "CentriqCTFAdminPassword1!"
$WeakUser = "student"
$WeakPassword = "P@ssw0rd"

#Create relative path for Desktop Image
$DesktopPath = Join-Path -Path $PSScriptRoot -ChildPath "bkgrd.png"

#Change Desktop Image
Set-ItemProperty `
    -path 'HKCU:\Control Panel\Desktop\' `
    -name wallpaper `
    -value $DesktopPath

# Create Admin User

$SecureAdminPass = ConvertTo-SecureString $AdminPassword -AsPlainText -Force

New-ADUser `
    -Name $AdminUser `
    -SamAccountName $AdminUser `
    -UserPrincipalName "$AdminUser@localnet.ctf" `
    -AccountPassword $SecureAdminPass `
    -Enabled $true `
    -DisplayName "Service Administrator" `
    -Description "CTF Admin Account" `
    -PasswordNeverExpires $true `
    -Path "CN=Users,DC=localnet,DC=ctf"

Add-ADGroupMember `
    -Identity "Domain Admins" `
    -Members $AdminUser


# Create Weak User Account

$SecureWeakPass = ConvertTo-SecureString $WeakPassword -AsPlainText -Force

New-ADUser `
    -Name $WeakUser `
    -SamAccountName $WeakUser `
    -UserPrincipalName "$WeakUser@localnet.ctf" `
    -AccountPassword $SecureWeakPass `
    -Enabled $true `
    -DisplayName "Student User" `
    -Description "CTF Weak User Account" `
    -Path "CN=Users,DC=localnet,DC=ctf"


$Interface = (Get-NetAdapter | Where-Object {$_.Status -eq "Up"}).Name

# Configure Static IP
New-NetIPAddress `
    -InterfaceAlias $Interface `
    -IPAddress 10.10.10.1 `
    -PrefixLength 24 `
    -ErrorAction SilentlyContinue

Set-DnsClientServerAddress `
    -InterfaceAlias $Interface `
    -ServerAddresses 127.0.0.1


# Install DHCP
Install-WindowsFeature DHCP -IncludeManagementTools

Add-DhcpServerInDC `
    -DnsName "LNDC.localnet.ctf" `
    -IPAddress 10.10.10.1


# Create DHCP Scope
Add-DhcpServerv4Scope `
    -Name "CTF Scope" `
    -StartRange 10.10.10.50 `
    -EndRange 10.10.10.200 `
    -SubnetMask 255.255.255.0

Set-DhcpServerv4OptionValue `
    -DnsServer 10.10.10.1 `
    -DnsDomain "localnet.ctf"

Add-DhcpServerv4ExclusionRange `
-StartRange 10.10.10.1 `
-EndRange 10.10.10.20 `
-ScopeId 10.10.10.0


# Remove scheduled task so it doesn't run again
Unregister-ScheduledTask -TaskName "NetworkConfig" -Confirm:$false
Write-Host "Network Config Task has been unregistered."

netsh dhcp add securitygroups

Set-ItemProperty -Path registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ServerManager\Roles\12 -Name ConfigurationState -Value 2

Restart-Service dhcpserver

# Move flags to CTFShare

$SharePath = "C:\CTFShare"
$SetupPath = "C:\CTFSetup"
$files = @("smbv1_traffic.pcap", "flag1.txt", "decode.ps1")

if (-not (Test-Path $SharePath)){New-Item -ItemType Directory -Path $SharePath | Out-Null}

foreach ($file in $files){
$source = Join-Path $SetupPath $File
Copy-Item $source -Destination $SharePath -Force
}

#Verify Permissions set

$acl = Get-Acl $SharePath
$hasEveryoneRead = $acl.Access | Where-Object {
$_.IdentityReference -match "Everyone" -and
$_.FileSystemRights -match "Read"}

if (-not $hasEveryoneRead){icacls $SharePath /grant "Everyone:(R)" /T}

# restrict decode script to student-only


# create svc_admin access
$svc_path = "C:\CTFShare\decode.ps1"

icacls $svc_path /inheritance:r
icacls $svc_path /grant "student:(RX)"
icacls $svc_path /remove "Users" "Authenticated Users" "Everyone"

# Update Policies for Anon_Access and Restart SMB Service

# Variables
$shareName = "CTFShare"
$folderPath = "C:\CTFShare"
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"
$tempCfg = "C:\temp\secpol.cfg"

# Ensure temp folder exists
New-Item -Path "C:\temp" -ItemType Directory -Force | Out-Null

# Grant share permissions
Grant-SmbShareAccess -Name $shareName -AccountName "ANONYMOUS LOGON" -AccessRight Read -Force
Grant-SmbShareAccess -Name $shareName -AccountName "Everyone" -AccessRight Read -Force

# Grant NTFS permissions
$acl = Get-Acl $folderPath
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "ANONYMOUS LOGON",
    "ReadAndExecute",
    "ContainerInherit,ObjectInherit",
    "None",
    "Allow"
)
$acl.SetAccessRule($rule)
Set-Acl -Path $folderPath -AclObject $acl

# Update NullSessionShares
$currentShares = (Get-ItemProperty -Path $regPath -Name "NullSessionShares" -ErrorAction SilentlyContinue).NullSessionShares
if ($currentShares -and ($currentShares -notcontains $shareName)) {
    $updatedShares = [string[]]($currentShares + $shareName)
} elseif ($currentShares) {
    $updatedShares = [string[]]$currentShares
} else {
    $updatedShares = [string[]]@($shareName)
}
Set-ItemProperty -Path $regPath -Name "NullSessionShares" -Value $updatedShares

# Export local security policy
secedit /export /cfg $tempCfg

# Append ANONYMOUS LOGON to "Access this computer from the network" right
$cfg = Get-Content $tempCfg
for ($i = 0; $i -lt $cfg.Count; $i++) {
    if ($cfg[$i] -match '^SeNetworkLogonRight\s*=') {
        if ($cfg[$i] -notmatch 'S-1-5-7') {
            $cfg[$i] = $cfg[$i] + ",*S-1-5-7"
        }
    }
}
$cfg | Set-Content $tempCfg

# Apply updated security policy
secedit /configure /db C:\Windows\security\local.sdb /cfg $tempCfg /areas USER_RIGHTS


# Check if the account is a member of Domain Admins
$IsAdmin = Get-ADGroupMember "Domain Admins" | Where-Object { $_.SamAccountName -eq $AdminUser }

if ($IsAdmin) {

    Write-Host "$AdminUser is a Domain Administrator."

    # Find the built-in Administrator account (RID 500)
    $BuiltInAdmin = Get-ADUser -Filter * -Properties SID,Enabled | Where-Object {
        $_.SID.Value -match "-500$"
    }

    if ($BuiltInAdmin.Enabled) {

        Disable-ADAccount -Identity $BuiltInAdmin.SamAccountName
        Write-Host "Built-in Domain Administrator account disabled."

    } else {

        Write-Host "Built-in Domain Administrator already disabled."
    }

} else {

    Write-Host "$AdminUser is NOT a Domain Administrator. Built-in admin will remain enabled."
}

# fix for command "smbclient -L //10.10.10.1 -U%" not working
$lsaPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
Set-ItemProperty -Path $lsaPath -Name "EveryoneIncludesAnonymous" -Value 1 -Type DWord
Set-ItemProperty -Path $lsaPath -Name "TurnOffAnonymousBlock" -Value 0 -Type DWord
Set-ItemProperty -Path $lsaPath -Name "RestrictAnonymous" -Value 0 -Type DWord
Set-ItemProperty -Path $lsaPath -Name "RestrictAnonymousSAM" -Value 0 -Type DWord
$lanmanPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"
Set-ItemProperty -Path $lanmanPath -Name "NullSessionPipes" -Value @("srvsvc","lsarpc","samr") -Type MultiString

# Restart SMB service to apply all changes
Restart-Service LanManServer -Force
Restart-Service LanmanWorkstation -Force -ErrorAction SilentlyContinue

Restart-Computer -Force

Pause
