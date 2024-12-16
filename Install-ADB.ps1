[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Install for all users (requires admin rights)")]
    [switch]$SystemWide,
    
    [Parameter(HelpMessage = "Force reinstallation even if already installed")]
    [switch]$Force,

    [Parameter(HelpMessage = "Show help message")]
    [switch]$Help
)

# Constants
$DOWNLOAD_URL = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
$DEFAULT_INSTALL_PATH = "$env:LOCALAPPDATA\Android\Sdk\platform-tools"
$TEMP_DIR = "$env:TEMP\platform-tools-install"
$BACKUP_DIR = "$env:TEMP\platform-tools-backup"

# Enable TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Test-InternetConnection {
    [CmdletBinding()]
    param()
    try {
        $response = Invoke-WebRequest -Uri "https://dl.google.com" -UseBasicParsing -TimeoutSec 5
        return $true
    }
    catch {
        return $false
    }
}

function Test-PreRequisites {
    [CmdletBinding()]
    param (
        [switch]$Force
    )

    Write-Verbose "Starting prerequisite checks..."
    $results = @{
        ShouldInstall = $false
        Message       = ""
    }

    # Check disk space
    Write-Verbose "Checking disk space..."
    $drive = Split-Path $DEFAULT_INSTALL_PATH -Qualifier
    $freeSpace = (Get-PSDrive $drive.TrimEnd(":")).Free
    $spaceRequirement = 100MB
    if ($freeSpace -lt $spaceRequirement) {
        $results.Message = "Insufficient disk space. Need at least 100MB free."
        return $results
    }

    # Check existing installation
    Write-Verbose "Checking existing installation..."
    if ((Test-Path "$DEFAULT_INSTALL_PATH\adb.exe") -and -not $Force) {
        try {
            $adbTest = Start-Job { & "$using:DEFAULT_INSTALL_PATH\adb.exe" version }
            if (Wait-Job $adbTest -Timeout 5) {
                $adbVersion = Receive-Job $adbTest
                if ($adbVersion -match "Android Debug Bridge") {
                    $results.Message = "ADB is already installed and working correctly at: $DEFAULT_INSTALL_PATH"
                    return $results
                }
            }
            Remove-Job $adbTest -Force -ErrorAction SilentlyContinue
        }
        catch {
            Write-Verbose "Existing ADB installation appears corrupted: $_"
        }
    }

    # Check internet connection
    Write-Verbose "Checking internet connection..."
    if (-not (Test-InternetConnection)) {
        $results.Message = "No internet connection available."
        return $results
    }

    $results.ShouldInstall = $true
    return $results
}

function Show-Help {
    $helpText = @"
Install-ADB.ps1
Installs Android Debug Bridge (ADB) platform tools and configures system PATH

USAGE:
    .\Install-ADB.ps1 [options]

OPTIONS:
    -SystemWide     Install for all users (requires admin rights)
    -Force         Force reinstallation even if already installed
    -Help          Show this help message

EXAMPLES:
    .\Install-ADB.ps1                     # Install for current user
    .\Install-ADB.ps1 -SystemWide         # Install system-wide
    .\Install-ADB.ps1 -Force              # Force reinstall
"@
    Write-Host $helpText
    exit 0
}

if ($Help) {
    Show-Help
    exit 0
}

function Backup-ExistingInstallation {
    [CmdletBinding()]
    param()

    if (Test-Path $DEFAULT_INSTALL_PATH) {
        Write-Host "Backing up existing installation..." -ForegroundColor Yellow
        if (Test-Path $BACKUP_DIR) { Remove-Item $BACKUP_DIR -Recurse -Force }
        Copy-Item -Path $DEFAULT_INSTALL_PATH -Destination $BACKUP_DIR -Recurse
    }
}

# Main installation flow
try {
    # Pre-flight checks
    $preCheck = Test-PreRequisites -Force:$Force
    if (-not $preCheck.ShouldInstall) {
        if ($preCheck.Message) {
            Write-Host $preCheck.Message -ForegroundColor Yellow
        }
        exit 0
    }

    # Ensure admin rights if system-wide installation requested
    if ($SystemWide) {
        if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "System-wide installation requires admin rights. Please run as Administrator."
        }
    }

    # Create directories
    $null = New-Item -ItemType Directory -Force -Path @(
        $TEMP_DIR
        "$env:LOCALAPPDATA\Android\Sdk"
    )

    Write-Host "Starting ADB installation..." -ForegroundColor Yellow

    # Backup existing installation
    Backup-ExistingInstallation

    # Download with progress bar
    Write-Host "Downloading platform-tools..." -ForegroundColor Yellow
    $zipPath = "$TEMP_DIR\platform-tools.zip"
    $ProgressPreference = 'SilentlyContinue'
    $response = Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile $zipPath
    $ProgressPreference = 'Continue'

    # Verify download
    if (-not (Test-Path $zipPath) -or (Get-Item $zipPath).Length -eq 0) {
        throw "Download failed or file is empty"
    }

    # Remove existing installation if needed
    if (Test-Path $DEFAULT_INSTALL_PATH) {
        Remove-Item $DEFAULT_INSTALL_PATH -Recurse -Force
    }

    # Extract with progress
    Write-Host "Extracting..." -ForegroundColor Yellow
    Expand-Archive -Path $zipPath -DestinationPath "$env:LOCALAPPDATA\Android\Sdk" -Force

    # Update PATH
    $pathScope = if ($SystemWide) { "Machine" } else { "User" }
    $currentPath = [Environment]::GetEnvironmentVariable("Path", $pathScope)
    
    if ($currentPath -notlike "*$DEFAULT_INSTALL_PATH*") {
        $newPath = $currentPath + ";" + $DEFAULT_INSTALL_PATH
        [Environment]::SetEnvironmentVariable("Path", $newPath, $pathScope)
    }

    # Verify installation
    $env:Path = [Environment]::GetEnvironmentVariable("Path", $pathScope)
    $null = & "$DEFAULT_INSTALL_PATH\adb.exe" version
    Write-Host "ADB installed successfully!" -ForegroundColor Green

}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    
    # Restore backup if available
    if (Test-Path $BACKUP_DIR) {
        Write-Host "Restoring previous installation..." -ForegroundColor Yellow
        Copy-Item -Path $BACKUP_DIR -Destination $DEFAULT_INSTALL_PATH -Recurse -Force
    }
    
    exit 1
}
finally {
    # Cleanup
    @($TEMP_DIR, $BACKUP_DIR) | ForEach-Object {
        if (Test-Path $_) {
            Remove-Item $_ -Recurse -Force
        }
    }
}