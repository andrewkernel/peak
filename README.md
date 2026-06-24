# Peak Utility

Peak Utility is a Windows PowerShell launcher for structured PC optimization workflows. It provides an authenticated menu for diagnostics, refresh tasks, setup steps, installers, graphics settings, Windows settings, hardware checks, and advanced scripts.

## What It Does

- Requires a local sign-in before exposing optimization actions.
- Elevates through Windows UAC when administrator privileges are needed.
- Creates a Windows restore point before changes when the user accepts the prompt.
- Discovers numbered optimization folders such as `1 Check`, `2 Refresh`, and `8 Advanced`.
- Runs `.ps1`, `.bat`, `.cmd`, `.url`, and `.lnk` items from a consistent menu.
- Logs each executed item and exit code to `PeakUtility.log`.

## Files

```text
PeakUtility.ps1   Main authenticated PowerShell launcher
PeakUtility.bat   Convenience launcher for double-click usage
```

## Usage

Run from PowerShell:

```powershell
.\PeakUtility.ps1
```

Run a setup check without executing optimization items:

```powershell
.\PeakUtility.ps1 -SelfTest
```

Show help:

```powershell
.\PeakUtility.ps1 -Help
```

## Safety Model

Peak Utility is designed to make risky system work more deliberate:

- It separates diagnostic, refresh, setup, graphics, Windows, hardware, and advanced workflows into visible menu groups.
- It prompts for a restore point before entering the main workflow.
- It logs execution history for traceability.
- It does not store plaintext passwords. Local sign-in data is salted and hashed in `PeakUtility.auth.json`.

## Requirements

- Windows
- PowerShell
- Administrator rights for system-level actions
- Optimization folders placed beside the launcher, or a manually selected root folder when prompted

## Status

This public repository contains the launcher layer. Some operational scripts, client-specific workflows, packaged assets, or private optimization bundles may be excluded from the public repo.

## License

All rights reserved unless a license is added later.
