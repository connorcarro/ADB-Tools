# ADB-Tools

This project contains PowerShell scripts to install Android Debug Bridge (ADB) platform tools and configure the system PATH.

## Scripts

### Set-ADBPath.ps1

This script sets or removes the ADB path in the system PATH.

#### Usage

```powershell
.\Set-ADBPath.ps1              # Interactive mode
.\Set-ADBPath.ps1 -Remove      # Remove ADB from PATH
.\Set-ADBPath.ps1 -CustomPath -Path "C:\path\to\adb"  # Set custom path
.\Set-ADBPath.ps1 -Silent      # No prompts
```

#### Parameters

- `-CustomPath`: Use a custom path for ADB.
- `-Silent`: Run without prompts.
- `-Remove`: Remove ADB from PATH.
- `-Path`: Specify the custom path for ADB.

### Install-ADB.ps1

This script installs the ADB platform tools and configures the system PATH.

#### Usage

```powershell
.\Install-ADB.ps1                     # Install for current user
.\Install-ADB.ps1 -SystemWide         # Install system-wide
.\Install-ADB.ps1 -Force              # Force reinstall
.\Install-ADB.ps1 -Help               # Show help message
```

#### Parameters

- `-SystemWide`: Install for all users (requires admin rights).
- `-Force`: Force reinstallation even if already installed.
- `-Help`: Show help message.

## Requirements

- PowerShell 5.1 or later
- Internet connection for downloading ADB platform tools

## Notes

- Ensure you run the scripts with appropriate permissions (e.g., as Administrator for system-wide changes).
- The scripts handle both user-level and system-level PATH modifications.
