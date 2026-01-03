This repository contains a collection of Active Directory enumeration scripts designed specifically for real-world internal security assessments, assumed breach scenarios, and red team engagements—including hardened enterprise environments where traditional tooling often fails.

The scripts focus on living-off-the-land techniques, using only native Windows capabilities, with graceful fallbacks when PowerShell or advanced modules are restricted.

Why This Repository Exists:
Modern enterprise environments commonly enforce:
1. EDR / XDR solutions (Defender, CrowdStrike, Sentinel, etc.)
2. AMSI, Script Block Logging, and constrained PowerShell
3. AppLocker / WDAC policies
4. Disabled Python and third-party binaries
5. Restricted admin privileges

In such scenarios:
1. Dropping tools is noisy or impossible
2. PowerShell scripts (.ps1) may be blocked
3. RSAT / AD modules may not be installed

These scripts are built for those exact conditions.

These scripts are provided for educational and authorized security testing purposes only.
