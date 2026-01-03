#requires -version 3
$ErrorActionPreference = "Continue"

function New-OutputFolder {
    $ts = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $out = "AD_ENUM_ADMODULE_$ts"
    New-Item -ItemType Directory -Path $out -Force | Out-Null
    return (Resolve-Path $out).Path
}

function Write-Banner($mode) {
    Clear-Host
    Write-Host "===============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "        AD ENUMERATION SCRIPT BY ABC" -ForegroundColor Yellow
    Write-Host "        MODE: $mode" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "===============================================================" -ForegroundColor Green
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

Write-Banner "POWERSHELL AD MODULE (RSAT/AD cmdlets)"
"AD ENUMERATION SCRIPT BY ABC" | Out-File $Map -Encoding UTF8
"MODE: POWERSHELL AD MODULE (RSAT/AD cmdlets)" | Add-Content $Map
"Output Folder: $OutDir" | Add-Content $Map
"" | Add-Content $Map
"Files generated (what each contains):" | Add-Content $Map
"" | Add-Content $Map

# Load AD module if available
Run-AndSave $OutDir "01_import_ad_module.txt" "Import-Module ActiveDirectory (availability check)" {
    Import-Module ActiveDirectory -ErrorAction SilentlyContinue
    if (Get-Module ActiveDirectory) { "ActiveDirectory module loaded." } else { "ActiveDirectory module NOT available." }
}
Save-MapLine $Map "01_import_ad_module.txt" "Import-Module ActiveDirectory (availability check)"

if (-not (Get-Module ActiveDirectory)) {
    Write-Host "[!] ActiveDirectory module not available. Exiting AD-module script." -ForegroundColor Red
    Write-Host "[*] You can run the ADSI script instead."
    return
}

# Domain / Forest / DCs
Run-AndSave $OutDir "02_get_addomain.txt" "Domain information (Get-ADDomain)" { Get-ADDomain }
Save-MapLine $Map "02_get_addomain.txt" "Domain information (Get-ADDomain)"

Run-AndSave $OutDir "03_get_adforest.txt" "Forest information (Get-ADForest)" { Get-ADForest }
Save-MapLine $Map "03_get_adforest.txt" "Forest information (Get-ADForest)"

Run-AndSave $OutDir "04_domain_controllers.txt" "Domain controllers (Get-ADDomainController -Filter *)" {
    Get-ADDomainController -Filter * | Select HostName,IPv4Address,Site,IsGlobalCatalog,OperationMasterRoles
}
Save-MapLine $Map "04_domain_controllers.txt" "Domain controllers list"

# Users / Groups / Privileged groups
Run-AndSave $OutDir "05_domain_users.txt" "Domain users (SamAccountName)" {
    Get-ADUser -Filter * | Select SamAccountName
}
Save-MapLine $Map "05_domain_users.txt" "Domain users (SamAccountName)"

Run-AndSave $OutDir "06_domain_admins_members.txt" "Domain Admins members" { Get-ADGroupMember "Domain Admins" }
Save-MapLine $Map "06_domain_admins_members.txt" "Domain Admins members"

Run-AndSave $OutDir "07_enterprise_admins_members.txt" "Enterprise Admins members (may fail if not in forest root)" {
    Get-ADGroupMember "Enterprise Admins"
}
Save-MapLine $Map "07_enterprise_admins_members.txt" "Enterprise Admins members"

# Password/account hygiene
Run-AndSave $OutDir "08_pwd_never_expires_users.txt" "Users with PasswordNeverExpires" {
    Get-ADUser -Filter {PasswordNeverExpires -eq $true} | Select SamAccountName,Enabled
}
Save-MapLine $Map "08_pwd_never_expires_users.txt" "Users with PasswordNeverExpires"

Run-AndSave $OutDir "09_pwd_not_required_users.txt" "Users with PasswordNotRequired" {
    Get-ADUser -Filter {PasswordNotRequired -eq $true} | Select SamAccountName,Enabled
}
Save-MapLine $Map "09_pwd_not_required_users.txt" "Users with PasswordNotRequired"

Run-AndSave $OutDir "10_inactive_users_60d.txt" "Users inactive 60+ days (LastLogonDate)" {
    Get-ADUser -Filter * -Properties LastLogonDate |
        Where-Object {$_.LastLogonDate -and $_.LastLogonDate -lt (Get-Date).AddDays(-60)} |
        Select SamAccountName,LastLogonDate
}
Save-MapLine $Map "10_inactive_users_60d.txt" "Users inactive 60+ days (LastLogonDate)"

Run-AndSave $OutDir "11_disabled_users.txt" "Disabled users (Enabled -eq false)" {
    Get-ADUser -Filter {Enabled -eq $false} | Select SamAccountName,DistinguishedName
}
Save-MapLine $Map "11_disabled_users.txt" "Disabled users"

# Computers / OS
Run-AndSave $OutDir "12_computers.txt" "Computers list" { Get-ADComputer -Filter * | Select Name }
Save-MapLine $Map "12_computers.txt" "Computers list"

Run-AndSave $OutDir "13_computers_pwd_never_expires.txt" "Computers with PasswordNeverExpires" {
    Get-ADComputer -Filter {PasswordNeverExpires -eq $true} | Select Name
}
Save-MapLine $Map "13_computers_pwd_never_expires.txt" "Computers with PasswordNeverExpires"

Run-AndSave $OutDir "14_computers_os.txt" "Computers OS inventory" {
    Get-ADComputer -Filter * -Properties OperatingSystem | Select Name,OperatingSystem
}
Save-MapLine $Map "14_computers_os.txt" "Computers OS inventory"

# ADCS objects (AD module via Get-ADObject)
Run-AndSave $OutDir "15_adcs_presence.txt" "ADCS presence (pKIEnrollmentService objects)" {
    Get-ADObject -Filter 'objectClass -eq "pKIEnrollmentService"' | Select Name,DistinguishedName
}
Save-MapLine $Map "15_adcs_presence.txt" "ADCS presence"

Run-AndSave $OutDir "16_cert_templates.txt" "Certificate templates (pKICertificateTemplate objects)" {
    Get-ADObject -Filter 'objectClass -eq "pKICertificateTemplate"' | Select Name,DistinguishedName
}
Save-MapLine $Map "16_cert_templates.txt" "Certificate templates"

Run-AndSave $OutDir "17_cert_templates_flags.txt" "Template flags (basic indicator fields)" {
    Get-ADObject -Filter 'objectClass -eq "pKICertificateTemplate"' `
        -Properties msPKI-Enrollment-Flag,msPKI-Template-Schema-Version |
        Select Name,msPKI-Enrollment-Flag,msPKI-Template-Schema-Version
}
Save-MapLine $Map "17_cert_templates_flags.txt" "Template flags (basic indicator fields)"

# Trusts
Run-AndSave $OutDir "18_domain_trusts.txt" "Domain trust enumeration (Get-ADTrust -Filter *)" {
    Get-ADTrust -Filter * | Select Name,TrustType,TrustDirection,ForestTransitive
}
Save-MapLine $Map "18_domain_trusts.txt" "Domain trust enumeration"

# AS-REP / Kerberoast
Run-AndSave $OutDir "19_asrep_candidates.txt" "AS-REP candidates (DoesNotRequirePreAuth)" {
    Get-ADUser -Filter {DoesNotRequirePreAuth -eq $true} | Select SamAccountName,Enabled
}
Save-MapLine $Map "19_asrep_candidates.txt" "AS-REP candidates (DoesNotRequirePreAuth)"

Run-AndSave $OutDir "20_kerberoast_spn_users.txt" "Kerberoast candidates (ServicePrincipalName not null)" {
    Get-ADUser -Filter {ServicePrincipalName -ne "$null"} -Properties ServicePrincipalName |
        Select SamAccountName,ServicePrincipalName
}
Save-MapLine $Map "20_kerberoast_spn_users.txt" "Kerberoast candidates (SPN set)"

# Session timeout GPO check (GroupPolicy module may be missing)
Run-AndSave $OutDir "21_gpo_timeout_candidates.txt" "Session timeout policy search (Get-GPO -All) - requires GroupPolicy module" {
    Import-Module GroupPolicy -ErrorAction SilentlyContinue
    if (-not (Get-Module GroupPolicy)) {
        "GroupPolicy module not available."
    } else {
        Get-GPO -All | Where-Object {$_.DisplayName -match "Idle|Session|Timeout"} | Select DisplayName,Id
    }
}
Save-MapLine $Map "21_gpo_timeout_candidates.txt" "Session timeout GPO search (if GroupPolicy module exists)"

# --- Local host checks (same as ADSI version) ---
Run-AndSave $OutDir "22_local_admins.txt" "Local Administrators group members" { Get-LocalGroupMember Administrators }
Save-MapLine $Map "22_local_admins.txt" "Local Administrators group members"

Run-AndSave $OutDir "23_saved_creds_dirs.txt" "Saved credentials directories listing" {
    "User creds dir: $env:APPDATA\Microsoft\Credentials"
    dir "$env:APPDATA\Microsoft\Credentials" -ErrorAction SilentlyContinue
    ""
    "SystemProfile creds dir: C:\Windows\System32\config\systemprofile\AppData\Local\Microsoft\Credentials"
    dir "C:\Windows\System32\config\systemprofile\AppData\Local\Microsoft\Credentials" -ErrorAction SilentlyContinue
}
Save-MapLine $Map "23_saved_creds_dirs.txt" "Saved credentials directories listing"

Run-AndSave $OutDir "24_execution_policy.txt" "Execution policy list" { Get-ExecutionPolicy -List }
Save-MapLine $Map "24_execution_policy.txt" "Execution policy list"

Run-AndSave $OutDir "25_execution_policy_bypass_check.txt" "ExecutionPolicy bypass check (spawns powershell with -ExecutionPolicy Bypass)" {
    powershell -ExecutionPolicy Bypass -Command "Get-Date"
}
Save-MapLine $Map "25_execution_policy_bypass_check.txt" "ExecutionPolicy bypass check"

Run-AndSave $OutDir "26_unquoted_service_paths.txt" "Unquoted service path candidates (auto-start, spaces, no quotes)" {
    Get-WmiObject Win32_Service |
        Where-Object { $_.StartMode -eq "Auto" -and $_.PathName -match " " -and $_.PathName -notmatch '"' } |
        Select Name,PathName,StartName
}
Save-MapLine $Map "26_unquoted_service_paths.txt" "Unquoted service path candidates"

Run-AndSave $OutDir "27_services_running_as_domain_users.txt" "Services running as non-LocalSystem identities" {
    Get-WmiObject Win32_Service |
        Where-Object { $_.StartName -notmatch "LocalSystem|NT AUTHORITY" } |
        Select Name,StartName,State,PathName
}
Save-MapLine $Map "27_services_running_as_domain_users.txt" "Services running as non-LocalSystem identities"

Run-AndSave $OutDir "28_schtasks_verbose.txt" "Scheduled tasks verbose" { schtasks /query /fo LIST /v }
Save-MapLine $Map "28_schtasks_verbose.txt" "Scheduled tasks verbose"

Run-AndSave $OutDir "29_firewall_profiles.txt" "Firewall profiles" { Get-NetFirewallProfile }
Save-MapLine $Map "29_firewall_profiles.txt" "Firewall profiles"

Run-AndSave $OutDir "30_amsi_status.txt" "AMSI registry status" { Get-ItemProperty HKLM:\Software\Microsoft\AMSI -ErrorAction SilentlyContinue }
Save-MapLine $Map "30_amsi_status.txt" "AMSI registry status"

Run-AndSave $OutDir "31_powershell_version.txt" "PowerShell version table" { $PSVersionTable }
Save-MapLine $Map "31_powershell_version.txt" "PowerShell version table"

Run-AndSave $OutDir "32_language_mode.txt" "PowerShell Language Mode" { $ExecutionContext.SessionState.LanguageMode }
Save-MapLine $Map "32_language_mode.txt" "PowerShell Language Mode"

Run-AndSave $OutDir "33_lsa_runasppl.txt" "LSA Protection (RunAsPPL)" { Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\Lsa -Name RunAsPPL -ErrorAction SilentlyContinue }
Save-MapLine $Map "33_lsa_runasppl.txt" "LSA Protection (RunAsPPL)"

Run-AndSave $OutDir "34_dpapi_masterkeys_user.txt" "DPAPI user Protect recursive listing" { Get-ChildItem "$env:APPDATA\Microsoft\Protect" -Recurse -ErrorAction SilentlyContinue }
Save-MapLine $Map "34_dpapi_masterkeys_user.txt" "DPAPI user Protect recursive listing"

Run-AndSave $OutDir "35_dpapi_masterkeys_system.txt" "DPAPI system Protect recursive listing" { Get-ChildItem "C:\Windows\System32\Microsoft\Protect" -Recurse -ErrorAction SilentlyContinue }
Save-MapLine $Map "35_dpapi_masterkeys_system.txt" "DPAPI system Protect recursive listing"

Run-AndSave $OutDir "36_ldsecsvc.txt" "LDSecSvc status (Credential Guard indicator)" { Get-Service LDSecSvc -ErrorAction SilentlyContinue }
Save-MapLine $Map "36_ldsecsvc.txt" "LDSecSvc status"

Run-AndSave $OutDir "37_ports_listening.txt" "Listening ports (Get-NetTCPConnection -State Listen)" { Get-NetTCPConnection -State Listen }
Save-MapLine $Map "37_ports_listening.txt" "Listening ports"

Run-AndSave $OutDir "38_services_all.txt" "Services inventory (Get-Service)" { Get-Service }
Save-MapLine $Map "38_services_all.txt" "Services inventory"

Run-AndSave $OutDir "39_smb_sessions.txt" "SMB sessions (Get-SmbSession) - may require admin" { Get-SmbSession -ErrorAction SilentlyContinue }
Save-MapLine $Map "39_smb_sessions.txt" "SMB sessions"

Run-AndSave $OutDir "40_smb_shares.txt" "SMB shares (Get-SmbShare)" { Get-SmbShare -ErrorAction SilentlyContinue }
Save-MapLine $Map "40_smb_shares.txt" "SMB shares"

# Defender cmdlets (if present)
Run-AndSave $OutDir "41_defender_status.txt" "Defender status (Get-MpComputerStatus) - if available" {
    if (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue) {
        Get-MpComputerStatus | Select RealTimeProtectionEnabled,IsTamperProtected,MAPSReporting,AMSIEnabled
    } else {
        "Get-MpComputerStatus not available on this system."
    }
}
Save-MapLine $Map "41_defender_status.txt" "Defender status (Get-MpComputerStatus) - if available"

Run-AndSave $OutDir "42_defender_exclusions.txt" "Defender exclusions (Get-MpPreference) - if available" {
    if (Get-Command Get-MpPreference -ErrorAction SilentlyContinue) {
        Get-MpPreference | Select ExclusionPath,ExclusionProcess,ExclusionExtension,EnableScriptScanning
    } else {
        "Get-MpPreference not available on this system."
    }
}
Save-MapLine $Map "42_defender_exclusions.txt" "Defender exclusions (Get-MpPreference) - if available"

# Hardcoded credential scan (file content)
Run-AndSave $OutDir "43_hardcoded_creds_filesearch.txt" "Keyword search for secrets in common file types (can be slow)" {
    Get-ChildItem C:\ -Include *.txt,*.ini,*.config,*.xml -Recurse -ErrorAction SilentlyContinue |
        Select-String "password|pwd|secret|token|apikey" -ErrorAction SilentlyContinue
}
Save-MapLine $Map "43_hardcoded_creds_filesearch.txt" "Keyword search for secrets in common file types"

Write-Host ""
Write-Host "[*] Completed. Outputs saved in: $OutDir"
Write-Host "[*] Open 00_README_FILES.txt for the file map."
