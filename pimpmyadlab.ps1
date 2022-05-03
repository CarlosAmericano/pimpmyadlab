﻿#Requires -RunAsAdministrator
 
# TCM-ACADEMY Practical Ethical Hacker Course - Active Directory Lab build script 
# DomainController (Hydra-DC) and Both Workstation (Punisher & Spiderman)
# https://academy.tcm-sec.com/p/practical-ethical-hacking-the-complete-course
#
# Scripted By: Dewalt         
# Revision 1.0.3 - see readme.md for revision notes   
#    
# Special Thanks to :
#  ToddAtLarge (PNPT Certified) for the NukeDefender script 
#  Yaseen (PNPT Certified) for Alpha/Beta Testing!
#  uCald4aMarine Release Candidate Testing
# 
#  -- Autoconfigured IP Addresses --
#  DC will always have ip x.x.x.250
#  Punsiher will always have ip x.x.x.220 
#  Spirderman will always have ip x.x.x.221
#  DNS On the DC is set to 127.0.0.1
#  DNS On Workstations is set to DC's ip of x.x.x.250 
#

# ---- begin nuke defender function
function nukedefender { 
  $ErrorActionPreference = "SilentlyContinue"

  # disable uac, firewall, defender
  write-host("`n  [++] Nuking Defender")
  reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /f /v EnableLUA /t REG_DWORD /d 0 > $null
  reg add "HKLM\System\CurrentControlSet\Services\SecurityHealthService" /v "Start" /t REG_DWORD /d "4" /f > $null

  # remove defender reg hive if it exists
  # reg delete "HKLM\Software\Policies\Microsoft\Windows Defender" /f > $null
  
  # defender av go bye bye! 
  reg add "HKLM\Software\Policies\Microsoft\Windows Defender" /v "DisableAntiSpyware" /t REG_DWORD /d "1" /f > $null
  reg add "HKLM\Software\Policies\Microsoft\Windows Defender" /v "DisableAntiVirus" /t REG_DWORD /d "1" /f > $null
  reg add "HKLM\Software\Policies\Microsoft\Windows Defender\MpEngine" /v "MpEnablePus" /t REG_DWORD /d "0" /f > $null
  reg add "HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableBehaviorMonitoring" /t REG_DWORD /d "1" /f > $null
  reg add "HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableIOAVProtection" /t REG_DWORD /d "1" /f > $null
  reg add "HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableOnAccessProtection" /t REG_DWORD /d "1" /f > $null
  reg add "HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableRealtimeMonitoring" /t REG_DWORD /d "1" /f > $null
  reg add "HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableScanOnRealtimeEnable" /t REG_DWORD /d "1" /f > $null
  reg add "HKLM\Software\Policies\Microsoft\Windows Defender\Reporting" /v "DisableEnhancedNotifications" /t REG_DWORD /d "1" /f > $null
  reg add "HKLM\Software\Policies\Microsoft\Windows Defender\SpyNet" /v "DisableBlockAtFirstSeen" /t REG_DWORD /d "1" /f > $null
  reg add "HKLM\Software\Policies\Microsoft\Windows Defender\SpyNet" /v "SpynetReporting" /t REG_DWORD /d "0" /f > $null
  reg add "HKLM\Software\Policies\Microsoft\Windows Defender\SpyNet" /v "SubmitSamplesConsent" /t REG_DWORD /d "2" /f > $null
  reg add "HKLM\System\CurrentControlSet\Control\WMI\Autologger\DefenderApiLogger" /v "Start" /t REG_DWORD /d "0" /f > $null
  reg add "HKLM\System\CurrentControlSet\Control\WMI\Autologger\DefenderAuditLogger" /v "Start" /t REG_DWORD /d "0" /f > $null
  
  # disable services 
  write-host("`n  [++] Nuking Defender Related Services")
  schtasks /Change /TN "Microsoft\Windows\ExploitGuard\ExploitGuard MDM policy Refresh" /Disable > $null
  schtasks /Change /TN "Microsoft\Windows\Windows Defender\Windows Defender Cache Maintenance" /Disable > $null
  schtasks /Change /TN "Microsoft\Windows\Windows Defender\Windows Defender Cleanup" /Disable > $null
  schtasks /Change /TN "Microsoft\Windows\Windows Defender\Windows Defender Scheduled Scan" /Disable > $null
  schtasks /Change /TN "Microsoft\Windows\Windows Defender\Windows Defender Verification" /Disable > $null

  # disable windows update/automatic update
  write-host("`n  [++] Nuking Windows Update")
  reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v "NoAutoUpdate" /t REG_DWORD /d "1" /f > $null

  # disable remote uac ( should solved the rcp_s_access_denied issue with Impacket may need to include w/ workstations )
  write-host("`n  [++] Nuking UAC and REMOTE UAC")
  reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "LocalAccountTokenFilterPolicy" /t REG_DWORD /d "1" /f > $null

  # enable icmp-echo on ipv4 and ipv6 (should not be required firewall is off)
  write-host("`n  [++] Enabling ICMP ECHO on IPv4 and IPv6")
  netsh advfirewall firewall add rule name="ICMP Allow incoming V4 echo request" protocol=icmpv4:8,any dir=in action=allow > $null
  netsh advfirewall firewall add rule name="ICMP Allow incoming V6 echo request" protocol=icmpv6:8,any dir=in action=allow > $null

  # enable Network Discovery
  write-host("`n  [++] Enabling Network Discovery")
  Get-NetFirewallRule -DisplayGroup 'Network Discovery'|Set-NetFirewallRule -Profile 'Private, Domain' `
  -Enabled true -PassThru|select Name,DisplayName,Enabled,Profile|ft -a | Out-Null

  # disable all firewalling (public, private, domain) - Server and Workstations
  write-host("`n  [++] Disabling Windows Defender Firewalls : Public, Private, Domain")
  Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled False | Out-Null
  }
  # ---- end nukedefender

# ---- begin remove_all_updates  
function remove_all_updates {
  Get-WmiObject -query "Select HotFixID  from Win32_QuickFixengineering" | sort-object -Descending -Property HotFixID|%{
    $sUpdate=$_.HotFixID.Replace("KB","")
    write-host ("Uninstalling update "+$sUpdate);
    & wusa.exe /uninstall /KB:$sUpdate /quiet /norestart;
    Wait-Process wusa
        Start-Sleep -s 1 }
  }
  # ---- end remove_all_updates 

# ---- begin build_lab function 
function build_lab {
  $ErrorActionPreference = "SilentlyContinue"
  write-host("`n  When prompted you are being logged out simply click the Close button")
  remove_all_updates 

  # disable server manager from launch at startup
  write-host("`n  [++] Disabling Server Manager from launching on startup ")
  Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask | Out-Null

  # download and install latest version of git from github
  setup_git

  # git clone powersploit from powershellmafia
  git_powersploit

  # install ad-domain-services
  write-host("`n  [++] Installing Module Active Directory Domain Services (ADDS)")
  Install-windowsfeature -name AD-Domain-Services -IncludeManagementTools -WarningAction SilentlyContinue | Out-Null

  # import activedirectory module
  write-host("`n  [++] Importing Module ActiveDirectory")
  Import-Module ActiveDirectory -WarningAction SilentlyContinue | Out-Null

  # install adds 
  write-host("`n  [++] Installing ADDS Domain : Marvel.local ")
  Install-ADDSDomain -SkipPreChecks -ParentDomainName MARVEL -NewDomainName local -NewDomainNetbiosName MARVEL `
  -InstallDns -SafeModeAdministratorPassword (Convertto-SecureString -AsPlainText "P@$$w0rd!" -Force) -Force -WarningAction SilentlyContinue | Out-Null

  # create adds forest marvel.local
  write-host("`n  [++] Deploying Active Directory Domain Forest in MARVEL.local")
  Install-ADDSForest -SkipPreChecks -CreateDnsDelegation:$false -DatabasePath "C:\Windows\NTDS" `
  -DomainMode "WinThreshold" -DomainName "MARVEL.local" -DomainNetbiosName "MARVEL" `
  -ForestMode "WinThreshold" -InstallDns:$true -LogPath "C:\Windows\NTDS" -NoRebootOnCompletion:$false `
  -SysvolPath "C:\Windows\SYSVOL" -Force:$true `
  -SafeModeAdministratorPassword (Convertto-SecureString -AsPlainText "P@$$w0rd!" -Force) -WarningAction SilentlyContinue | Out-Null

  write-host("`n  Note: Do NOT REBOOT MANUALLY - Let me reboot on my own! I am A BIG COMPUTER NOW!! I GOT THIS!! `n")
  }
  # ---- end build_adlab function

# ---- begin create_labcontent function
function create_labcontent {
  $ErrorActionPreference = "SilentlyContinue"
  
  # install ad-certificate services
  write-host("`n  [++] Installing Active Directory Certificate Services")
  Add-WindowsFeature -Name AD-Certificate -IncludeManagementTools -WarningAction SilentlyContinue | Out-Null
  
  # install ad-certificate authority
  write-host("`n  [++] Installing Active Directory Certificate Authority")
  Add-WindowsFeature -Name Adcs-Cert-Authority -IncludeManagementTools -WarningAction SilentlyContinue | Out-Null

  # configure ad-certificate authority
  write-host("`n  [++] Configuring Active Directory Certificate Authority")
  Install-AdcsCertificationAuthority -CAType EnterpriseRootCa -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" `
  -KeyLength 2048 -HashAlgorithmName SHA1 -ValidityPeriod Years -ValidityPeriodUnits 99 -WarningAction SilentlyContinue -Force | Out-Null

  # install remote system administration tools
  write-host("`n  [++] Installing Remote System Administration Tools (RSAT)")
  Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0 -WarningAction SilentlyContinue | Out-Null

  # install rsat-adcs and rsat-adcs-management 
  write-host("`n  [++] Installing RSAT-ADCS and RSAT-ADCS-Management")
  Add-WindowsFeature RSAT-ADCS,RSAT-ADCS-mgmt -WarningAction SilentlyContinue | Out-Null

  # create C:\share\hacke me and smbshare
  write-host("`n  [++] Creating Share C:\Share\hackme - Permissions Everyone FullAccess")
  mkdir C:\Share\hackme > $null
  New-SmbShare -Name "hackme" -Path "C:\Share\hackme" -ChangeAccess "Users" -FullAccess "Everyone" -WarningAction SilentlyContinue | Out-Null

  # smb signing is enabled but not required (breakout into individual fix function)
  write-host("`n  [++] Setting Registry Keys SMB Signing Enabled but not Required")
  reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v "RequireSecuritySignature" /t REG_DWORD /d "0" /f > $null
  reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v "requiresecuritysignature" /t REG_DWORD /d "0" /f > $null

  # printer-nightmare registry keys (breakout into individual fix function)
  write-host("`n  [++] Setting Registry Keys for PrinterNightmare")
  reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint" /v "NoWarningNoElevationOnInstall" /t REG_DWORD /d "1" /f > $null
  reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint" /v "RestrictDriverInstallationToAdministrators" /t REG_DWORD /d "0" /f > $null

  # set localaccounttokenfilterpolicy
  reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\system" /v "LocalAccountTokenFilterPolicy" /t REG_DWORD /d "1" /f

  # set alwaysinstallelevated 
  red add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Installer" -v "AlwaysInstallElevated" /t REG_DWORD /d "1" /f > $null 
  
  # set dns config of ethernet card on dc to 127.0.0.1
  $adapter=Get-CimInstance -Class Win32_NetworkAdapter -Property NetConnectionID,NetConnectionStatus | Where-Object { $_.NetConnectionStatus -eq 2 } | Select-Object -Property NetConnectionID -ExpandProperty NetConnectionID
  write-host("`n  [++] Setting DNS Server to 127.0.0.1 on interface $adapter")
  Set-DNSClientServerAddress "$adapter" -ServerAddresses ("127.0.0.1") | Out-Null

  # create user pparker
  New-ADUser -Name "Peter Parker" -GivenName "Peter" -Surname "Parker" -SamAccountName "pparker" `
  -UserPrincipalName "pparker@$Global:Domain -Path DC=marvel,DC=local" `
  -AccountPassword (ConvertTo-SecureString "Password2" -AsPlainText -Force) `
  -PasswordNeverExpires $true -PassThru | Enable-ADAccount  | Out-Null
  Write-Host "`n  [++] User: Peter Parker added, Logon: pparker Password: Password2"
  Write-Host "        Adding Peter Parker to Marvel.local Groups: Domain Users"

  # create user fcastle
  New-ADUser -Name "Frank Castle" -GivenName "Frank" -Surname "Castle" -SamAccountName "fcastle" `
  -UserPrincipalName "fcastle@$Global:Domain -Path DC=marvel,DC=local" `
  -AccountPassword (ConvertTo-SecureString "Password1" -AsPlainText -Force) `
  -PasswordNeverExpires $true -PassThru | Enable-ADAccount  | Out-Null

  # if the rps_s_access_denited is fixed by the reg key, fcastle no longer needs to be a domain admin
  Add-ADGroupMember -Identity "Domain Admins" -Members fcastle  | Out-Null
  Write-Host "`n  [++] User: Frank Castle added, Logon: fcastle Password: Password1"
  Write-Host "        Adding Frank Castle to Marvel.local Groups: Domain Users, Domain Admins"

  # create user tstark 
  New-ADUser -Name "`n  [++] User: Tony Stark" -GivenName "Tony" -Surname "Stark" -SamAccountName "tstark" `
  -UserPrincipalName "tstark@$Global:Domain -Path DC=marvel,DC=local" `
  -AccountPassword (ConvertTo-SecureString "Password2019!@#" -AsPlainText -Force) `
  -PasswordNeverExpires $true -PassThru | Enable-ADAccount | Out-Null

  Add-ADGroupMember -Identity "Administrators" -Members tstark
  Add-ADGroupMember -Identity "Domain Admins" -Members tstark
  Write-Host "`n  [++] User: Tony Stark added, Logon: tstark Password: Password2019!@#"
  Write-Host "        Adding Tony Stark to Marvel.local Groups: Administrators, Domain Admins"

  # create user sqlservice 
  New-ADUser -Name "SQL Service" -GivenName "SQL" -Surname "Service" -SamAccountName "sqlservice" `
  -UserPrincipalName "sqlservice@$Global:Domain -Path DC=marvel,DC=local" `
  -AccountPassword (ConvertTo-SecureString "MYpassword123#" -AsPlainText -Force) `
  -PasswordNeverExpires $true -Description "Password is MYpassword123#" -PassThru | Enable-ADAccount | Out-Null

  Add-ADGroupMember -Identity "Administrators" -Members sqlservice | Out-Null
  Add-ADGroupMember -Identity "Domain Admins" -Members sqlservice | Out-Null
  Add-ADGroupMember -Identity "Enterprise Admins" -Members sqlservice | Out-Null
  Add-ADGroupMember -Identity "Group Policy Creator Owners" -Members sqlservice | Out-Null
  Add-ADGroupMember -Identity "Schema Admins" -Members sqlservice | Out-Null
  Write-Host "`n  [++] User: SQL Service added, Logon Name: sqlservice Password: MYpassword123#" 
  Write-Host "        Adding SQLService to Marvel.local Groups: Administrators, Domain Admins, Enterprise Admins, Group Policy Creator Owners, Schema Admins"

  # setspn for sqlservice user
  # delete existing spns
  write-host("`n  [++] Deleting Existing SPNs")
  setspn -D SQLService/MARVEL.local HYDRA-DC > $null
  setspn -D SQLService/Marvel.local MARVEL\SQLService > $null
  setspn -D HYDRA-DC/SQLService.MARVEL.local:60111 MARVEL\SQLService > $null
  setspn -D MARVEL/SQLService.Marvel.local:60111 MARVEL\SQLService > $null
  setspn -D DomainController/SQLService.MARVEL.Local:60111 MARVEL\SQLService > $null

  # add the new spn
  write-host("`n  [++] Adding SPNs")
  setspn -A HYDRA-DC/SQLService.MARVEL.local:60111 MARVEL\SQLService > $null
  setspn -A SQLService/MARVEL.local  MARVEL\SQLService > $null
  setspn -A DomainController/SQLService.MARVEL.local:60111 MARVEL\SQLService > $null

  # check both local and domain spns (add additional if statements here)
  write-host("`n  [++] Checking Local Hydra-DC SPN")
  setspn -L HYDRA-DC
  write-host("`n  [++] Checking MARVEL\SQLService SPN")
  setspn -L MARVEL\SQLService

  # create ou=groups, move all existing groups into ou=groups,dc=marvel,dc=local
  New-ADOrganizationalUnit -Name "Groups" -Path "DC=MARVEL,DC=LOCAL" -Description "Groups" | Out-Null
  get-adgroup "Schema Admins" | move-adobject -targetpath "OU=Groups,DC=MARVEL,DC=LOCAL" | Out-Null
  get-adgroup "Allowed RODC Password Replication Group" | move-adobject -targetpath "OU=Groups,DC=MARVEL,DC=LOCAL" | Out-Null
  get-adgroup "Cert Publishers" | move-adobject -targetpath "OU=Groups,DC=MARVEL,DC=LOCAL" | Out-Null
  get-adgroup "Cloneable Domain Controllers" | move-adobject -targetpath "OU=Groups,DC=MARVEL,DC=LOCAL" | Out-Null
  get-adgroup "Denied RODC Password Replication Group" | move-adobject -targetpath "OU=Groups,DC=MARVEL,DC=LOCAL" | Out-Null
  get-adgroup "DnsAdmins" | move-adobject -targetpath "OU=Groups,DC=MARVEL,DC=LOCAL" | Out-Null
  get-adgroup "DnsUpdateProxy" | move-adobject -targetpath "OU=Groups,DC=MARVEL,DC=LOCAL" | Out-Null
  get-adgroup "Domain Computers" | move-adobject -targetpath "OU=Groups,DC=MARVEL,DC=LOCAL" | Out-Null
  get-adgroup "Domain Controllers" | move-adobject -targetpath "OU=Groups,DC=MARVEL,DC=LOCAL" | Out-Null
  get-adgroup "Domain Guests" | move-adobject -targetpath "OU=Groups,DC=MARVEL,DC=LOCAL" | Out-Null
  get-adgroup "Domain Users" | move-adobject -targetpath "OU=Groups,DC=MARVEL,DC=LOCAL" | Out-Null
  get-adgroup "Domain Admins" | move-adobject -targetpath "OU=Groups,DC=MARVEL,DC=LOCAL" | Out-Null
  get-adgroup "Enterprise Admins" | move-adobject -targetpath "OU=Groups,DC=MARVEL,DC=LOCAL" | Out-Null
  get-adgroup "Enterprise Key Admins" | move-adobject -targetpath "OU=Groups,DC=MARVEL,DC=LOCAL" | Out-Null
  get-adgroup "Enterprise Read-only Domain Controllers" | move-adobject -targetpath "OU=Groups,DC=MARVEL,DC=LOCAL" | Out-Null
  get-adgroup "Group Policy Creator Owners" | move-adobject -targetpath "OU=Groups,DC=MARVEL,DC=LOCAL" | Out-Null
  get-adgroup "Key Admins" | move-adobject -targetpath "OU=Groups,DC=MARVEL,DC=LOCAL" | Out-Null
  get-adgroup "Protected Users" | move-adobject -targetpath "OU=Groups,DC=MARVEL,DC=LOCAL" | Out-Null
  get-adgroup "RAS and IAS Servers" | move-adobject -targetpath "OU=Groups,DC=MARVEL,DC=LOCAL" | Out-Null
  get-adgroup "Read-only Domain Controllers" | move-adobject -targetpath "OU=Groups,DC=MARVEL,DC=LOCAL" | Out-Null
  }
  # ---- end create_labcontent function

# ---- begin set_dcstaticip function  
function set_dcstaticip { 
  # get the ip address
  $IPAddress=Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $(Get-NetConnectionProfile | Select-Object -ExpandProperty InterfaceIndex) | Select-Object -ExpandProperty IPAddress
  
  # get the adapetr name
  $adapter=Get-CimInstance -Class Win32_NetworkAdapter -Property NetConnectionID,NetConnectionStatus | Where-Object { $_.NetConnectionStatus -eq 2 } | Select-Object -Property NetConnectionID -ExpandProperty NetConnectionID
  
  # split the ip address up based on the . 
  $IPByte = $IPAddress.Split(".")
  
  # first 3 octets not intrested in, only the last octet set to .250 (ip address)
  $StaticIP = ($IPByte[0]+"."+$IPByte[1]+"."+$IPByte[2]+".250") 

  # first 3 octets not intrested in, onlly the last octet set to .1 (default gateway)
  $StaticGateway = ($IPByte[0]+"."+$IPByte[1]+"."+$IPByte[2]+".1") 

  # static mask of 24 bits or 255.255.255.0
  $StaticMask = 24 

  # ipv4
  $IpType = "IPv4"
  
  # ip address parameteres list
  $ipParams = @{
  InterfaceAlias = "$adapter"
  IPAddress = "$StaticIP"
  PrefixLength = $StaticMask
  DefaultGateway = "$StaticGateway"
  AddressFamily = "IPv4"
  }
  
  # dns parameters list 
  $dnsParams = @{
  InterfaceAlias = "$adapter"
  ServerAddresses = ("8.8.8.8")
  }
  
  # write to screen what were doing 
  write-host "$StaticIP / $StaticGateway"
  
  $upadapter = Get-NetAdapter | ? {$_.Status -eq "up"}
  
  # remove config if any 
  If (($upadapter | Get-NetIPConfiguration).IPv4Address.IPAddress) {$upadapter | Remove-NetIPAddress -AddressFamily $IPType -Confirm:$false}
  If (($upadapter | Get-NetIPConfiguration).Ipv4DefaultGateway) {$upadapter | Remove-NetRoute -AddressFamily $IPType -Confirm:$false}
  
  # make sure its not set for dhcp anymore
  Set-NetIPInterface -InterfaceAlias "$adapter" -Dhcp Disabled
  
  # set the new ip address to .250 and the default gateway to .1  subnet = 255.255.255.0
  New-NetIPAddress @ipParams

  # set the dns based on parameters
  Set-DnsClientServerAddress @dnsParams
  
  # restart the network adapter
  Restart-NetAdapter "$adapter"
  }
  # ---- end set_dcstaticip function  

# ---- begin set_punisher_staticip function  
function set_punisher_staticip { 
  # get the ip address
  $IPAddress=Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $(Get-NetConnectionProfile | Select-Object -ExpandProperty InterfaceIndex) | Select-Object -ExpandProperty IPAddress
  
  # get the adapetr name
  $adapter=Get-CimInstance -Class Win32_NetworkAdapter -Property NetConnectionID,NetConnectionStatus | Where-Object { $_.NetConnectionStatus -eq 2 } | Select-Object -Property NetConnectionID -ExpandProperty NetConnectionID
   
  # split the ip address up based on the . 
  $IPByte = $IPAddress.Split(".")
   
  # first 3 octets not intrested in, only the last octet set to .250 (ip address)
  $StaticIP = ($IPByte[0]+"."+$IPByte[1]+"."+$IPByte[2]+".220") 
 
  # first 3 octets not intrested in, onlly the last octet set to .1 (default gateway)
  $StaticGateway = ($IPByte[0]+"."+$IPByte[1]+"."+$IPByte[2]+".1") 
 
  # static mask of 24 bits or 255.255.255.0
  $StaticMask = 24 
 
  # ipv4
  $IpType = "IPv4"
   
  # ip address parameteres list
  $ipParams = @{
  InterfaceAlias = "$adapter"
  IPAddress = "$StaticIP"
  PrefixLength = $StaticMask
  DefaultGateway = "$StaticGateway"
  AddressFamily = "IPv4"
  }
   
  # dns parameters list 
  $dnsParams = @{
  InterfaceAlias = "$adapter"
  ServerAddresses = ("8.8.8.8")
  }
   
  # write to screen what were doing 
  write-host "$StaticIP / $StaticGateway"
   
  $upadapter = Get-NetAdapter | ? {$_.Status -eq "up"}
   
  # remove config if any 
  If (($upadapter | Get-NetIPConfiguration).IPv4Address.IPAddress) {$upadapter | Remove-NetIPAddress -AddressFamily $IPType -Confirm:$false}
  If (($upadapter | Get-NetIPConfiguration).Ipv4DefaultGateway) {$upadapter | Remove-NetRoute -AddressFamily $IPType -Confirm:$false}
   
  # make sure its not set for dhcp anymore
  Set-NetIPInterface -InterfaceAlias "$adapter" -Dhcp Disabled
   
  # set the new ip address to .250 and the default gateway to .1  subnet = 255.255.255.0
  New-NetIPAddress @ipParams
 
  # set the dns based on parameters
  Set-DnsClientServerAddress @dnsParams
   
  # restart the network adapter
  Restart-NetAdapter "$adapter"
  }
  # ---- end set_punisher_staticip function  

# ---- begin set_spiderman_staticip function  
function set_spiderman_staticip { 
  # get the ip address
  $IPAddress=Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $(Get-NetConnectionProfile | Select-Object -ExpandProperty InterfaceIndex) | Select-Object -ExpandProperty IPAddress
  
  # get the adapetr name
  $adapter=Get-CimInstance -Class Win32_NetworkAdapter -Property NetConnectionID,NetConnectionStatus | Where-Object { $_.NetConnectionStatus -eq 2 } | Select-Object -Property NetConnectionID -ExpandProperty NetConnectionID
  
  # split the ip address up based on the . 
  $IPByte = $IPAddress.Split(".")
  
  # first 3 octets not intrested in, only the last octet set to .250 (ip address)
  $StaticIP = ($IPByte[0]+"."+$IPByte[1]+"."+$IPByte[2]+".221") 

  # first 3 octets not intrested in, onlly the last octet set to .1 (default gateway)
  $StaticGateway = ($IPByte[0]+"."+$IPByte[1]+"."+$IPByte[2]+".1") 

  # static mask of 24 bits or 255.255.255.0
  $StaticMask = 24 

  # ipv4
  $IpType = "IPv4"
  
  # ip address parameteres list
  $ipParams = @{
  InterfaceAlias = "$adapter"
  IPAddress = "$StaticIP"
  PrefixLength = $StaticMask
  DefaultGateway = "$StaticGateway"
  AddressFamily = "IPv4"
  }
  
  # dns parameters list 
  $dnsParams = @{
  InterfaceAlias = "$adapter"
  ServerAddresses = ("8.8.8.8")
  }
  
  # write to screen what were doing 
  write-host "$StaticIP / $StaticGateway"
  
  $upadapter = Get-NetAdapter | ? {$_.Status -eq "up"}
  
  # remove config if any 
  If (($upadapter | Get-NetIPConfiguration).IPv4Address.IPAddress) {$upadapter | Remove-NetIPAddress -AddressFamily $IPType -Confirm:$false}
  If (($upadapter | Get-NetIPConfiguration).Ipv4DefaultGateway) {$upadapter | Remove-NetRoute -AddressFamily $IPType -Confirm:$false}
  
  # make sure its not set for dhcp anymore
  Set-NetIPInterface -InterfaceAlias "$adapter" -Dhcp Disabled
  
  # set the new ip address to .250 and the default gateway to .1  subnet = 255.255.255.0
  New-NetIPAddress @ipParams

  # set the dns based on parameters
  Set-DnsClientServerAddress @dnsParams
  
  # restart the network adapter
  Restart-NetAdapter "$adapter"
  }  
  # ---- end set_spiderman_staticip function

# ---- begin server_build function
function server_build {
  Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask | Out-Null
  write-host("`n`n   Computer Name : $machine")
  write-host("     Domain Name : $domain")
  write-host("      OS Version : $osversion")

  if($currentname -ne "HYDRA-DC") {
      write-host("`n  Computer Name is Incorrect Setting HYDRA-DC")
      write-host("`n  - Script Run 1 of 3 - Setting the computer name to HYDRA-DC and rebooting")
      write-host("`n  AFTER The reboot run the script again! to setup the domain controller!")
      Read-Host -Prompt "`n Press ENTER to continue..."
      set_dcstaticip
      Rename-Computer -NewName "HYDRA-DC" -Restart
      }
      elseif ($domain -ne "MARVEL.LOCAL") {
        write-host("`n  Computer name is CORRECT... Executing BuildLab Function")
        write-host("`n  Script Run 2 of 3 - AFTER The Domain Controller has been setup and configured, the system will auto-reboot")
        write-host("`n  NOTE: This Reboot will take SEVERAL MINUTES, Dont Panic! We are working hard to build your Course Domain-Controller!")
        write-host("`n  AFTER THE REBOOT run this script 1 more time and select menu option D")
        Read-Host -Prompt "`n`n Press ENTER to continue..."
        build_lab
        }
      elseif ($domain -eq "MARVEL.LOCAL" -And $machine -eq "HYDRA-DC") {
        write-host("`n Computer name and Domain are correct : Executing CreateContent Function ")
        create_labcontent
        write-host("`n Script Run 3 of 3 - We are all done! Rebooting one last time! o7 Happy Hacking! ")
        $dcip=Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $(Get-NetConnectionProfile | Select-Object -ExpandProperty InterfaceIndex) | Select-Object -ExpandProperty IPAddress
        write-host("`n`n Write this down! We need this in the Workstation Configruation... Domain Controller IP Address: $dcip `n`n")
        Read-Host -Prompt "`n`n Press ENTER to continue..."
        Restart-Computer
        }
      else {
        write-host("Giving UP! There is nothing to do!") }
      }
      # ---- end server_build function

# ---- begin git_powersploit function      
function git_powersploit {
  write-host("`n  [++] Git Cloning PowerSploit to $Env:windir\System32\WindowsPowerShell\v1.0\Modules\PowerSploit")
  git clone https://github.com/PowerShellMafia/PowerSploit $Env:windir\System32\WindowsPowerShell\v1.0\Modules\PowerSploit > $null 
  # Import-Module $Env:windir\System32\WindowsPowerShell\v1.0\Modules\PowerSploit\Recon
  # needs some additional work
  }
  # ---- end git_powersploit function

# ---- begin setup_git function
function setup_git {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $architecture = '64-bit'
  $assetName = "Git-*-$architecture.exe"
  
  $gitHubApi = 'https://api.github.com/repos/git-for-windows/git/releases/latest'
  $response = Invoke-WebRequest -Uri $gitHubApi -UseBasicParsing
  $json = $response.Content | ConvertFrom-Json
  $release = $json.assets | Where-Object Name -like $assetName
  
  # download 
  write-host("`n  [++] Downloading $($release.name)")
  Start-BitsTransfer -Source $release.browser_download_url -Destination ".\$($release.name)" | Out-Null
  
  # install  
  write-host("`n  [++] Installing $($release.name)")
  Start-Process .\$($release.name) -argumentlist "/silent /supressmsgboxes" -Wait  | Out-Null 
  rm .\$($release.name)  
  
  # reload environment variables 
  $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")  
  }
# ---- end setup_git function


# ---- begin workstations_common function
function workstations_common { 

  # remove all updates 
  remove_all_updates

  # download and install Git for Windows 
  setup_git 
  git_powersploit
  
  # install remote system administration tools
  write-host("`n  [++] Installing Remote System Administration Tools (RSAT)") 
  Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0 | Out-Null

  # install dotnet v2 - needed for powerview fix : powershell -version 2 -ep bypass 
  write-host("`n  [++] Installing .Net 2.0")
  Add-WindowsCapability -Online -Name NetFx2~~~~ | Out-Null
    
  # install dotnet v3 
  write-host("`n  [++] Installing .Net 3.0")
  Add-WindowsCapability -Online -Name NetFx3~~~~ | Out-Null 

  # download old version of Powerview so it works with course material 
  # requires .net v2 and the powershell -version 2 -ep bypass for this 
  # (course material update for this one)
  mkdir C:\TCM-ACADEMY > $null 
  write-host("`n  [++] Downloading Powerview v1.9 to C:\TCM-Academy")
  Invoke-WebRequest  https://raw.githubusercontent.com/PowerShellEmpire/PowerTools/version_1.9/PowerView/powerview.ps1 -o C:\TCM-Academy\Powerview.ps1 | Out-Null
  
  # download and unzip pstools.zip to c:\pstools 
  write-host("`n  [++] Downloading PSTools to C:\TCM-Academy")
  Invoke-WebRequest  https://download.sysinternals.com/files/PSTools.zip -o C:\TCM-Academy\PStools.zip | Out-Null
  Start-BitsTransfer -Source "https://download.sysinternals.com/files/PSTools.zip" -Destination "C:\TCM-Aacademy\PSTools.zip" | Out-Null
  write-host("`n  [++] Extracting PSTools to C:\PSTools")
  Expand-Archive -Force C:\TCM-Academy\PSTools.zip C:\PSTools | Out-Null 
  
  # create c:\share and smbshare
  mkdir C:\Share > $null 
  New-SmbShare -Name "Share" -Path "C:\Share" -ChangeAccess "Users" -FullAccess "Everyone" -WarningAction SilentlyContinue | Out-Null
    
  # get dns and set dns-config to domain controller ip address
  # may change DCDNS to hydra-dc-ip for readability
  $DCDNS=(Test-Connection -comp HYDRA-DC -Count 1).ipv4address.ipaddressToString
  write-host(" Found HYDRA-DC At $DCDNS")
  $adapter=Get-CimInstance -Class Win32_NetworkAdapter -Property NetConnectionID,NetConnectionStatus | Where-Object { $_.NetConnectionStatus -eq 2 } | Select-Object -Property NetConnectionID -ExpandProperty NetConnectionID
  write-host(" Setting DNS Server to $DCDNS on adapter $adapter")
  Set-DNSClientServerAddress "$adapter" -ServerAddresses ("$DCDNS")

  # automatically join domain using tstark
  write-host("`n Joining machine to domain Marvel.local")
  add-computer -domainname "MARVEL.LOCAL" -username administrator -restart | Out-Null
  $domain = "MARVEL"
  $password = "Password2019!@#" | ConvertTo-SecureString -asPlainText -Force
  $username = "$domain\tstark" 
  $credential = New-Object System.Management.Automation.PSCredential($username,$password)
  Add-Computer -DomainName $domain -Credential $credential  | Out-Null 
  }
  # ---- end workstations_common function      

# ---- begin workstation_punisher function 
function workstation_punisher { 
  write-host("`n`n   Computer Name : $machine")
  write-host("     Domain Name : $domain")
  write-host("      OS Version : $osversion")

  if ($machine -ne "PUNISHER") { 
    write-host ("`n Setting the name of this machine to PUNISHER and rebooting automatically...")
    write-host (" Run this script 1 more time and select 'P' in the menu to join the domain")
    Read-Host -Prompt "`n Press ENTER to continue..."
    set_punisher_staticip 
    Rename-Computer -NewName "PUNISHER" -Restart
    }
    elseif ($machine -eq "PUNISHER") {
      workstations_common
      Read-Host -Prompt "`n All done! $machine is all setup! `n Press Enter to reboot and Login as MARVEL\fcastle and Password1 "
      restart-computer 
    }
    else { write-host("Nothing to do here") }
    } 
    # ---- end workstation_punisher function 
    
# ---- begin workstation_spiderman function
function workstation_spiderman { 
  write-host("`n`n   Computer Name : $machine")
  write-host("     Domain Name : $domain")
  write-host("      OS Version : $osversion")
  
  if ($machine -ne "SPIDERMAN") {
    write-host ("`n Setting the name of this machine to SPIDERMAN and rebooting automatically...")
    write-host (" Run this script 1 more time and select 'S' in the menu to join the domain")
    Read-Host -Prompt "`n Press ENTER to continue..."
    # set_spiderman_staticip
    Rename-Computer -NewName "SPIDERMAN" -Restart
    }
    elseif ($machine -eq "SPIDERMAN") {
      workstations_common 
      Read-Host -Prompt "`n All done! $machine is all setup! `n Press Enter to reboot and Login as MARVEL\pparker and Password2 "
      restart-computer 
      }
    else { write-host("Nothing to do here") }
    } 
    # ---- end workstation_spiderman function

# ---- begin menu function
function menu {
  do {
    Write-Host "`n`n`tTCM-Academy PEH Course AD-Lab Build Menu - Select an option`n"
    Write-Host "`tPress 'D' to setup Hydra-DC Domain Controller"
    Write-host "`t(must be run 3 times)`n"
    Write-Host "`tPress 'P' to setup Punisher Workstation and join the domain Marvel.local"
    Write-host "`t(must be run 2 times)`n"
    Write-Host "`tPress 'S' to setup Spiderman Workstation and join the domain Marvel.local" 
    Write-host "`t(must be run 2 times)`n"
    Write-host "`tPress 'N' to only run the NukeDefender Function`n"
    Write-Host "`tPress 'X' to Exit"
    $choice = Read-Host "`n`tEnter Choice" } until (($choice -eq 'P') -or ($choice -eq 'D') -or ($choice -eq 'S') -or ($choice -eq 'N') -or ($choice -eq 'X'))

  switch ($choice) {
    'D'{  Write-Host "`n You have selected Hydra-DC domain controller"
          nukedefender 
          server_build }
    'P'{  Write-Host "`n You have selected Punisher Workstation"
          nukedefender 
          workstation_punisher }
    'S'{  Write-Host "`n You have selected Spiderman Workstation"
          nukedefender 
          workstation_spiderman }
    'N'{  Write-Host "`n You have selected to only run the NukeDefender function"
          nukedefender }
    'X'{Return}
    }
  }
  # ---- begin menu function  

# ---- being main
  $ErrorActionPreference = "SilentlyContinue"
  clear 
  $currentname=$env:COMPUTERNAME
  $machine=$env:COMPUTERNAME
  $domain=$env:USERDNSDOMAIN
  $osversion=((Get-WmiObject -class Win32_OperatingSystem).Caption)

  write-host("`n`n   Computer Name : $machine")
  write-host("     Domain Name : $domain")
  write-host("      OS Version : $osversion")

  if ("$osversion" -eq "Microsoft Windows Server 2019 Standard Evaluation") 
    { menu }
    elseif ("$osversion" -eq "Microsoft Windows Server 2016 Standard Evaluation") 
    { menu }  
    elseif ("$osversion" -eq "Microsoft Windows 10 Enterprise Evaluation") 
    { menu }
    elseif ("$osversion" -like "Home") {      
      write-host("`n [!!] Windows Home is unable to join a domain, please use the correct version of windows")
      exit 
      }
    elseif ("$osversion" -like "Education") {
      write-host("`n [!!] Windows Educational versions cannot be used with this lab")
    }
    elseif ("$osversion" -like "Windows 11") {
      write-host("`n [!!] Windows 11 cannot be used with this lab")
      exit 
      }
    elseif ("$osversion" -like "Windows Server 2022") {
      write-host("`n [!!] Windows Server 2022 cannot be used with this lab")
      exit 
      }
    else { write-host("Unable to find a suitable OS Version for this lab - Exiting") 
      }
      # ---- end main
