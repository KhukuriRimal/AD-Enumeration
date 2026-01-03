@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul

cls
echo ===============================================================
echo.
echo        AD ENUMERATION SCRIPT BY ABC
echo        MODE: NATIVE CMD ONLY (NO POWERSHELL)
echo.
echo ===============================================================
echo.

REM Output directory with timestamp
for /f "tokens=1-3 delims=/" %%a in ("%date%") do set d=%%c-%%b-%%a
for /f "tokens=1-3 delims=:." %%a in ("%time%") do set t=%%a%%b%%c
set "OUTDIR=AD_ENUM_CMD_%d%_%t%"
mkdir "%OUTDIR%" 2>nul

set "MAP=%OUTDIR%\00_README_FILES.txt"
echo AD ENUMERATION SCRIPT BY ABC > "%MAP%"
echo MODE: NATIVE CMD ONLY (NO POWERSHELL) >> "%MAP%"
echo Output Folder: %OUTDIR% >> "%MAP%"
echo. >> "%MAP%"
echo Files generated (what each contains): >> "%MAP%"
echo. >> "%MAP%"

REM Helper: run cmd, save stdout+stderr to file, add mapping line
REM Usage: call :RUN "filename.txt" "Description" command...
:RUN
set "FILE=%~1"
set "DESC=%~2"
shift
shift
echo [*] %DESC%
echo     -> %OUTDIR%\%FILE%
echo - %FILE% : %DESC%>> "%MAP%"
cmd /c "%*" > "%OUTDIR%\%FILE%" 2>&1
echo.>> "%OUTDIR%\%FILE%"
goto :eof

REM -------------------- Core Domain / AD Context --------------------
call :RUN "01_domain_info.txt" "Domain info from systeminfo (joined domain / workgroup)" ^
 systeminfo ^| findstr /i "Domain"

call :RUN "02_logonserver.txt" "Current LOGONSERVER used by this session" ^
 cmd /c "echo LOGONSERVER=%LOGONSERVER%"

call :RUN "03_dc_enum_nltest.txt" "Domain Controller list via nltest (if available)" ^
 nltest /dclist:%USERDOMAIN%

call :RUN "04_domain_users_list.txt" "Domain users list via net user /domain" ^
 net user /domain

call :RUN "05_domain_groups_list.txt" "Domain groups list via net group /domain" ^
 net group /domain

call :RUN "06_domain_admins.txt" "Members of Domain Admins group" ^
 net group "Domain Admins" /domain

call :RUN "07_enterprise_admins.txt" "Members of Enterprise Admins group (may fail if not in forest root domain)" ^
 net group "Enterprise Admins" /domain

call :RUN "08_whoami.txt" "Current user context and privileges (whoami /groups /priv)" ^
 cmd /c "whoami & echo. & whoami /groups & echo. & whoami /priv"

call :RUN "09_domain_computers_netview.txt" "Domain computers visible via net view /domain" ^
 net view /domain

REM -------------------- OS / Network / Shares --------------------
call :RUN "10_os_version_ver.txt" "Basic OS version via ver" ^
 ver

call :RUN "11_systeminfo_full.txt" "Full systeminfo (OS, hotfixes, network, domain, etc.)" ^
 systeminfo

call :RUN "12_smb_local_netview.txt" "Local SMB visibility (net view)" ^
 net view

REM -------------------- RDP / Remote Helpers --------------------
call :RUN "13_rdp_client_presence.txt" "Checks if mstsc.exe (RDP client) exists on system" ^
 where mstsc

call :RUN "14_runas_presence.txt" "Checks if runas.exe is available" ^
 where runas

REM -------------------- WMIC / Services / Tasks --------------------
call :RUN "15_wmic_os.txt" "WMIC OS caption/version" ^
 wmic os get caption,version

call :RUN "16_wmic_useraccounts.txt" "WMIC local user accounts (name,SID)" ^
 wmic useraccount get name,sid

call :RUN "17_wmic_services_brief.txt" "WMIC services list brief (good for quick service inventory)" ^
 wmic service list brief

call :RUN "18_wmic_products.txt" "WMIC installed products (name,version) - may be slow on some systems" ^
 wmic product get name,version

call :RUN "19_schtasks_verbose.txt" "Scheduled tasks verbose listing (often contains juicy run-as details)" ^
 schtasks /query /fo LIST /v

call :RUN "20_spooler_service.txt" "Print Spooler service status" ^
 sc query spooler

call :RUN "21_firewall_profiles.txt" "Windows Firewall status for all profiles" ^
 netsh advfirewall show allprofiles

call :RUN "22_listening_ports_netstat.txt" "Listening ports via netstat (fallback for port visibility)" ^
 netstat -ano

REM -------------------- Security / Credential-Related --------------------
call :RUN "23_lsa_runasppl.txt" "LSA Protection (RunAsPPL) registry value" ^
 reg query HKLM\SYSTEM\CurrentControlSet\Control\Lsa /v RunAsPPL

call :RUN "24_dpapi_user_protect_dir.txt" "DPAPI user Protect folder listing" ^
 cmd /c "dir %APPDATA%\Microsoft\Protect /a /s"

call :RUN "25_dpapi_system_protect_dir.txt" "DPAPI system Protect folder listing" ^
 cmd /c "dir C:\Windows\System32\Microsoft\Protect /a /s"

call :RUN "26_kerberos_klist.txt" "Kerberos ticket cache (klist)" ^
 klist

REM -------------------- ADCS / Certutil (if present) --------------------
call :RUN "27_adcs_ping_certutil.txt" "ADCS presence check via certutil -config - -ping" ^
 certutil -config - -ping

call :RUN "28_cert_templates.txt" "Certificate templates via certutil -template" ^
 certutil -template

call :RUN "29_cert_templates_enrollee.txt" "Templates filtered for ENROLLEE keyword (basic risk indicator)" ^
 cmd /c "certutil -template ^| findstr /i ENROLLEE"

REM -------------------- Trusts / NetBIOS --------------------
call :RUN "30_domain_trusts_nltest.txt" "Domain trust relationships via nltest /domain_trusts" ^
 nltest /domain_trusts

call :RUN "31_netbios_local.txt" "Local NetBIOS names (nbtstat -n)" ^
 nbtstat -n

REM NOTE: nbtstat remote needs a target IP/name; left as placeholder file
echo [*] Remote NetBIOS query requires a target. > "%OUTDIR%\32_netbios_remote_placeholder.txt"
echo Example: nbtstat -A 10.10.10.10 >> "%OUTDIR%\32_netbios_remote_placeholder.txt"
echo - 32_netbios_remote_placeholder.txt : Remote NetBIOS query placeholder (needs TARGET) >> "%MAP%"

REM -------------------- Tools availability --------------------
call :RUN "33_regedit_gpedit_presence.txt" "Checks if regedit and gpedit exist on this system" ^
 cmd /c "where regedit & echo. & where gpedit.msc"

REM -------------------- Defender / AV (CMD-friendly) --------------------
call :RUN "34_defender_service_status.txt" "Windows Defender service status (WinDefend)" ^
 sc query WinDefend

call :RUN "35_defender_realtime_registry.txt" "Defender Real-Time Protection registry key (may not exist on all builds)" ^
 reg query "HKLM\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection"

call :RUN "36_av_products_wmi_securitycenter2.txt" "Installed AV products via WMI (SecurityCenter2)" ^
 wmic /namespace:\\root\SecurityCenter2 path AntiVirusProduct get displayName,productState

REM -------------------- Local Admins / Saved Creds --------------------
call :RUN "37_local_admins.txt" "Local Administrators group members" ^
 net localgroup administrators

call :RUN "38_saved_creds_cmdkey.txt" "Saved credentials via cmdkey /list" ^
 cmdkey /list

REM -------------------- Service path issues / Priv-esc indicators --------------------
call :RUN "39_unquoted_service_paths_candidates.txt" "Auto-start services path listing (manual review for unquoted paths)" ^
 cmd /c "wmic service get name,displayname,pathname,startmode ^| findstr /i auto"

REM -------------------- Hardcoded creds search (CMD findstr) --------------------
call :RUN "40_findstr_creds_common_paths.txt" "Search common config file types for credential keywords (may take time)" ^
 cmd /c "findstr /si /n /p \"password pwd secret key token apikey\" C:\*.txt C:\*.ini C:\*.config C:\*.xml"

REM -------------------- Registry credential keyword search --------------------
call :RUN "41_reg_cred_search_hklm.txt" "Registry search (HKLM) for 'password' strings (can be noisy/slow)" ^
 reg query HKLM /f password /t REG_SZ /s

call :RUN "42_reg_cred_search_hkcu.txt" "Registry search (HKCU) for 'password' strings (can be noisy/slow)" ^
 reg query HKCU /f password /t REG_SZ /s

echo.
echo [*] Completed. Outputs saved in: %OUTDIR%
echo [*] Open %MAP% to see what each file contains.
pause
endlocal
