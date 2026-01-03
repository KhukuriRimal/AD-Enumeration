#requires -version 3
$ErrorActionPreference = "Continue"

function New-OutputFolder {
    $ts = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $out = "AD_ENUM_ADSI_$ts"
    New-Item -ItemType Directory -Path $out -Force | Out-Null
    return (Resolve-Path $out).Path
}

function Write-Banner($mode) {
    Clear-Host
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "        AD ENUMERATION SCRIPT BY ABC" -ForegroundColor Yellow
    Write-Host "        MODE: $mode" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Save-MapLine($mapFile, $file, $desc) {
    Add-Content -Path $mapFile -Value ("- {0} : {1}" -f $file, $desc)
}

function Run-AndSave {
    param(
        [string]$OutDir,
        [string]$File,
        [string]$Description,
        [scriptblock]$Script
    )
    $path = Join-Path $OutDir $File
    Write-Host "[*] $Description"
    Write-Host "    -> $path"
    try {
        & $Script *>&1 | Out-File -FilePath $path -Encoding UTF8
    } catch {
        $_ | Out-File -FilePath $path -Encoding UTF8
    }
}

$OutDir = New-OutputFolder
$Map = Join-Path $OutDir "00_README_FILES.txt"

Write-Banner "POWERSHELL ADSI (NO AD MODULE)"
"AD ENUMERATION SCRIPT BY ABC" | Out-File $Map -Encoding UTF8
"MODE: POWERSHELL ADSI (NO AD MODULE)" | Add-Content $Map
"Output Folder: $OutDir" | Add-Content $Map
"" | Add-Content $Map
"Files generated (what each contains):" | Add-Content $Map
"" | Add-Content $Map

# Helper info
Run-AndSave $OutDir "01_mode_info.txt" "Script mode + environment basics" {
    "Mode: ADSI"
    "User: $env:USERNAME"
    "Domain: $env:USERDOMAIN"
    "Computer: $env:COMPUTERNAME"
    "LogonServer: $env:LOGONSERVER"
}
Save-MapLine $Map "01_mode_info.txt" "Script mode + environment basics"

# Domain / Forest
Run-AndSave $OutDir "02_domain_name.txt" "Domain name via .NET DirectoryServices" {
    ([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()).Name
}
Save-MapLine $Map "02_domain_name.txt" "Domain name via .NET DirectoryServices"

Run-AndSave $OutDir "03_forest_name.txt" "Forest name via .NET DirectoryServices" {
    ([System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()).Name
}
Save-MapLine $Map "03_forest_name.txt" "Forest name via .NET DirectoryServices"

# DCs
Run-AndSave $OutDir "04_domain_controllers.txt" "Domain controllers (Name, IPAddress)" {
    ([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()).DomainControllers |
        Select Name,IPAddress
}
Save-MapLine $Map "04_domain_controllers.txt" "Domain controllers (Name, IPAddress)"

# Users / Groups
Run-AndSave $OutDir "05_domain_users.txt" "Domain user enumeration (objectClass=user)" {
    ([adsisearcher]"(objectClass=user)").FindAll() |
        Select @{n="User";e={$_.Properties.samaccountname[0]}}
}
Save-MapLine $Map "05_domain_users.txt" "Domain user enumeration (objectClass=user)"

Run-AndSave $OutDir "06_domain_admins_members.txt" "Domain Admins group members via LDAP binding" {
    $group = [ADSI]"LDAP://CN=Domain Admins,CN=Users,$(([ADSI]'').distinguishedName)"
    $group.member
}
Save-MapLine $Map "06_domain_admins_members.txt" "Domain Admins group members via LDAP binding"

# Password policy indicators
Run-AndSave $OutDir "07_pwd_never_expires_users.txt" "Users with PasswordNeverExpires (UAC bit 65536)" {
    ([adsisearcher]"(&(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=65536))").FindAll() |
        Select @{n="User";e={$_.Properties.samaccountname[0]}}
}
Save-MapLine $Map "07_pwd_never_expires_users.txt" "Users with PasswordNeverExpires (UAC bit 65536)"

Run-AndSave $OutDir "08_pwd_not_required_users.txt" "Users with PasswordNotRequired (UAC bit 32)" {
    ([adsisearcher]"(&(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=32))").FindAll() |
        Select @{n="User";e={$_.Properties.samaccountname[0]}}
}
Save-MapLine $Map "08_pwd_not_required_users.txt" "Users with PasswordNotRequired (UAC bit 32)"

# Inactive users (lastLogonTimestamp)
Run-AndSave $OutDir "09_inactive_users_60d.txt" "Inactive users 60+ days based on lastLogonTimestamp" {
    $days = (Get-Date).AddDays(-60).ToFileTime()
    ([adsisearcher]"(&(objectClass=user)(lastLogonTimestamp<=$days))").FindAll() |
        Select @{n="User";e={$_.Properties.samaccountname[0]}}
}
Save-MapLine $Map "09_inactive_users_60d.txt" "Inactive users 60+ days based on lastLogonTimestamp"

# Computers + OS
Run-AndSave $OutDir "10_computers.txt" "Computer objects (objectClass=computer)" {
    ([adsisearcher]"(objectClass=computer)").FindAll() |
        Select @{n="Computer";e={$_.Properties.name[0]}}
}
Save-MapLine $Map "10_computers.txt" "Computer objects (objectClass=computer)"

Run-AndSave $OutDir "11_computers_pwd_never_expires.txt" "Computers with PasswordNeverExpires (UAC bit 65536)" {
    ([adsisearcher]"(&(objectClass=computer)(userAccountControl:1.2.840.113556.1.4.803:=65536))").FindAll() |
        Select @{n="Computer";e={$_.Properties.name[0]}}
}
Save-MapLine $Map "11_computers_pwd_never_expires.txt" "Computers with PasswordNeverExpires (UAC bit 65536)"

Run-AndSave $OutDir "12_computers_os.txt" "Computer OS inventory (name + operatingSystem)" {
    ([adsisearcher]"(objectClass=computer)").FindAll() |
        Select @{n="Computer";e={$_.Properties.name[0]}},
               @{n="OS";e={$_.Properties.operatingsystem[0]}}
}
Save-MapLine $Map "12_computers_os.txt" "Computer OS inventory (name + operatingSystem)"

# ADCS + Templates
Run-AndSave $OutDir "13_adcs_presence.txt" "ADCS presence (pKIEnrollmentService objects)" {
    ([adsisearcher]"(objectClass=pKIEnrollmentService)").FindAll() |
        Select @{n="CA";e={$_.Properties.name[0]}}
}
Save-MapLine $Map "13_adcs_presence.txt" "ADCS presence (pKIEnrollmentService objects)"

Run-AndSave $OutDir "14_cert_templates_all.txt" "Certificate templates (pKICertificateTemplate objects)" {
    ([adsisearcher]"(objectClass=pKICertificateTemplate)").FindAll() |
        Select @{n="Template";e={$_.Properties.name[0]}}
}
Save-MapLine $Map "14_cert_templates_all.txt" "Certificate templates (pKICertificateTemplate objects)"

Run-AndSave $OutDir "15_cert_templates_basic_flag.txt" "Templates with msPKI-Enrollment-Flag=1 (basic indicator)" {
    ([adsisearcher]"(&(objectClass=pKICertificateTemplate)(msPKI-Enrollment-Flag=1))").FindAll() |
        Select @{n="Template";e={$_.Properties.name[0]}}
}
Save-MapLine $Map "15_cert_templates_basic_flag.txt" "Templates with msPKI-Enrollment-Flag=1 (basic indicator)"

# Trusts
Run-AndSave $OutDir "16_domain_trusts.txt" "Domain trust relationships (.NET trust API)" {
    ([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()).GetAllTrustRelationships()
}
Save-MapLine $Map "16_domain_trusts.txt" "Domain trust relationships (.NET trust API)"

# Kerberos preauth disabled (AS-REP candidates)
Run-AndSave $OutDir "17_asrep_candidates.txt" "Kerberos pre-auth disabled users (UAC bit 4194304)" {
    ([adsisearcher]"(&(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=4194304))").FindAll() |
        Select @{n="User";e={$_.Properties.samaccountname[0]}}
}
Save-MapLine $Map "17_asrep_candidates.txt" "Kerberos pre-auth disabled users (UAC bit 4194304)"

# Kerberoastable (SPN)
Run-AndSave $OutDir "18_kerberoast_spn_users.txt" "Kerberoastable users (servicePrincipalName=*)" {
    ([adsisearcher]"(&(objectClass=user)(servicePrincipalName=*))").FindAll() |
        Select @{n="User";e={$_.Properties.samaccountname[0]}},
               @{n="SPN";e={$_.Properties.serviceprincipalname}}
}
Save-MapLine $Map "18_kerberoast_spn_users.txt" "Kerberoastable users (servicePrincipalName=*)"

# Disabled users
Run-AndSave $OutDir "19_disabled_users.txt" "Disabled users (UAC bit 2)" {
    ([adsisearcher]"(&(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=2))").FindAll() |
        Select @{n="User";e={$_.Properties.samaccountname[0]}}
}
Save-MapLine $Map "19_disabled_users.txt" "Disabled users (UAC bit 2)"

# Delegation
Run-AndSave $OutDir "20_constrained_delegation_users.txt" "Constrained delegation (users with msDS-AllowedToDelegateTo)" {
    ([adsisearcher]"(&(objectClass=user)(msDS-AllowedToDelegateTo=*))").FindAll() |
        Select @{n="Account";e={$_.Properties.samaccountname}},
               @{n="Delegation";e={$_.Properties.'msds-allowedtodelegateto'}}
}
Save-MapLine $Map "20_constrained_delegation_users.txt" "Constrained delegation (users with msDS-AllowedToDelegateTo)"

Run-AndSave $OutDir "21_constrained_delegation_computers.txt" "Constrained delegation (computers with msDS-AllowedToDelegateTo)" {
    ([adsisearcher]"(&(objectClass=computer)(msDS-AllowedToDelegateTo=*))").FindAll() |
        Select @{n="Computer";e={$_.Properties.name}}
}
Save-MapLine $Map "21_constrained_delegation_computers.txt" "Constrained delegation (computers with msDS-AllowedToDelegateTo)"

Run-AndSave $OutDir "22_unconstrained_delegation_computers.txt" "Unconstrained delegation computers (UAC bit 524288)" {
    ([adsisearcher]"(&(objectClass=computer)(userAccountControl:1.2.840.113556.1.4.803:=524288))").FindAll() |
        Select @{n="Computer";e={$_.Properties.name}}
}
Save-MapLine $Map "22_unconstrained_delegation_computers.txt" "Unconstrained delegation computers (UAC bit 524288)"

# AD object ACLs (domain root)
Run-AndSave $OutDir "23_domain_root_acls.txt" "Domain root ACLs (ObjectSecurity.Access) - abuse vector hunting" {
    $root = [ADSI]"LDAP://RootDSE"
    $domain = [ADSI]("LDAP://" + $root.defaultNamingContext)
    $domain.psbase.ObjectSecurity.Access
}
Save-MapLine $Map "23_domain_root_acls.txt" "Domain root ACLs (ObjectSecurity.Access)"

# ---- Local host checks (still useful in ADSI mode) ----
Run-AndSave $OutDir "24_powershell_version.txt" "PowerShell version table" { $PSVersionTable }
Save-MapLine $Map "24_powershell_version.txt" "PowerShell version table"

Run-AndSave $OutDir "25_language_mode.txt" "PowerShell Language Mode (Full/Constrained/Restricted)" { $ExecutionContext.SessionState.LanguageMode }
Save-MapLine $Map "25_language_mode.txt" "PowerShell Language Mode"

Run-AndSave $OutDir "26_execution_policy.txt" "PowerShell Execution Policy list" { Get-ExecutionPolicy -List }
Save-MapLine $Map "26_execution_policy.txt" "PowerShell Execution Policy list"

Run-AndSave $OutDir "27_lsa_runasppl.txt" "LSA Protection RunAsPPL registry value" { reg query HKLM\SYSTEM\CurrentControlSet\Control\Lsa /v RunAsPPL }
Save-MapLine $Map "27_lsa_runasppl.txt" "LSA Protection RunAsPPL registry value"

Run-AndSave $OutDir "28_klist.txt" "Kerberos tickets (klist)" { klist }
Save-MapLine $Map "28_klist.txt" "Kerberos tickets (klist)"

Run-AndSave $OutDir "29_dpapi_user_protect.txt" "DPAPI user Protect folder listing" { cmd /c "dir %APPDATA%\Microsoft\Protect /a /s" }
Save-MapLine $Map "29_dpapi_user_protect.txt" "DPAPI user Protect folder listing"

Run-AndSave $OutDir "30_dpapi_system_protect.txt" "DPAPI system Protect folder listing" { cmd /c "dir C:\Windows\System32\Microsoft\Protect /a /s" }
Save-MapLine $Map "30_dpapi_system_protect.txt" "DPAPI system Protect folder listing"

Run-AndSave $OutDir "31_local_admins.txt" "Local Administrators group members" { net localgroup administrators }
Save-MapLine $Map "31_local_admins.txt" "Local Administrators group members"

Run-AndSave $OutDir "32_saved_creds_cmdkey.txt" "Saved credentials via cmdkey /list" { cmdkey /list }
Save-MapLine $Map "32_saved_creds_cmdkey.txt" "Saved credentials via cmdkey /list"

Run-AndSave $OutDir "33_defender_service.txt" "Defender service (WinDefend) status" { sc query WinDefend }
Save-MapLine $Map "33_defender_service.txt" "Defender service (WinDefend) status"

Run-AndSave $OutDir "34_av_products_securitycenter2.txt" "Installed AV products via SecurityCenter2 WMI" {
    cmd /c "wmic /namespace:\\root\SecurityCenter2 path AntiVirusProduct get displayName,productState"
}
Save-MapLine $Map "34_av_products_securitycenter2.txt" "Installed AV products via SecurityCenter2 WMI"

Run-AndSave $OutDir "35_unquoted_service_paths_candidates.txt" "Unquoted service path candidates (auto-start, has spaces, no quotes)" {
    Get-WmiObject Win32_Service |
        Where-Object { $_.StartMode -eq "Auto" -and $_.PathName -match " " -and $_.PathName -notmatch '"' } |
        Select Name,StartName,PathName
}
Save-MapLine $Map "35_unquoted_service_paths_candidates.txt" "Unquoted service path candidates"

Run-AndSave $OutDir "36_services_running_as_users.txt" "Services running as non-LocalSystem identities" {
    Get-WmiObject Win32_Service |
        Where-Object { $_.StartName -notmatch "LocalSystem|NT AUTHORITY" } |
        Select Name,StartName,State,PathName
}
Save-MapLine $Map "36_services_running_as_users.txt" "Services running as non-LocalSystem identities"

Run-AndSave $OutDir "37_hardcoded_creds_filesearch.txt" "Hardcoded credential keyword scan in common file types (can be slow)" {
    Get-ChildItem C:\ -Include *.txt,*.ini,*.config,*.xml -Recurse -ErrorAction SilentlyContinue |
        Select-String "password|pwd|secret|token|apikey" -ErrorAction SilentlyContinue
}
Save-MapLine $Map "37_hardcoded_creds_filesearch.txt" "Hardcoded credential keyword scan in common file types"

Run-AndSave $OutDir "38_registry_password_hklm.txt" "Registry keyword search HKLM for 'password' (noisy/slow)" {
    cmd /c "reg query HKLM /f password /t REG_SZ /s"
}
Save-MapLine $Map "38_registry_password_hklm.txt" "Registry keyword search HKLM for 'password'"

Run-AndSave $OutDir "39_registry_password_hkcu.txt" "Registry keyword search HKCU for 'password' (noisy/slow)" {
    cmd /c "reg query HKCU /f password /t REG_SZ /s"
}
Save-MapLine $Map "39_registry_password_hkcu.txt" "Registry keyword search HKCU for 'password'"

Write-Host ""
Write-Host "[*] Completed. Outputs saved in: $OutDir"
Write-Host "[*] Open 00_README_FILES.txt for the file map."
