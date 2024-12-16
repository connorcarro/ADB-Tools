[CmdletBinding()]
param(
    [switch]$CustomPath,
    [switch]$Silent,
    [switch]$Remove,
    [string]$Path
)

# Help message
$helpText = @"
ADB Path Setter
Usage: 
    .\Set-ADBPath.ps1              # Interactive mode
    .\Set-ADBPath.ps1 -Remove      # Remove ADB from PATH
    .\Set-ADBPath.ps1 -CustomPath -Path "C:\path\to\adb"  # Set custom path
    .\Set-ADBPath.ps1 -Silent      # No prompts
"@

if ($PSBoundParameters.ContainsKey('Help')) {
    Write-Host $helpText
    exit 0
}

# Admin check
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Warning "Running without admin rights - will modify user PATH only"
}

# Handle removal
if ($Remove) {
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $platformToolsPath = if ($CustomPath -and $Path) { [Environment]::ExpandEnvironmentVariables($Path) } else { [Environment]::ExpandEnvironmentVariables("%USERPROFILE%\AppData\Local\Android\Sdk\platform-tools") }
    
    if ($currentPath.Split(';') -contains $platformToolsPath) {
        $newPath = ($currentPath.Split(';') | Where-Object { $_ -ne $platformToolsPath }) -join ';'
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        Write-Host "ADB path removed from PATH" -ForegroundColor Green
    } else {
        Write-Host "ADB path not found in PATH" -ForegroundColor Yellow
        Write-Host "Use -CustomPath to specify the path" -ForegroundColor Yellow
    }
    exit 0
}

# Path selection
if (-not $Silent) {
    if (-not $CustomPath) {
        $useDefault = Read-Host "Use default adb location? (Y/n)"
        if ($useDefault -eq '' -or $useDefault.ToLower().StartsWith('y')) {
            $adbPath = [Environment]::ExpandEnvironmentVariables("%USERPROFILE%\AppData\Local\Android\Sdk\platform-tools")
        }
        else {
            $CustomPath = $true
        }
    }

    if ($Custompath) {
        $adbPath = if ($Path) { $Path } else { Read-Host "Enter custom adb path >" }
        $adbPath = [Environment]::ExpandEnvironmentVariables($adbPath)
    }
}
else {
    $adbPath = [Environment]::ExpandEnvironmentVariables("%USERPROFILE%\AppData\Local\Android\Sdk\platform-tools")
}

if (-not (Test-Path $adbPath)) {
    Write-Host "ADB directory not found at: $adbPath" -ForeGroundColor Red
    Write-Host "Please make sure Android SDK is installed or provide valid path." -ForegroundColor Yellow
    exit 1
}

try {
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    
    # Check if path already exists
    if ($currentPath.Split(';') -contains $adbPath) {
        Write-Host "ADB path is already in PATH." -ForegroundColor Yellow
        exit 0
    }

    # Sanitize and add new path
    $paths = $currentPath.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries)
    $paths += $adbPath
    $newPath = $paths -join ';'

    # Set the new path with correct parameter order
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    
    # Verify update
    $updatedPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($updatedPath.Split(';') -contains $adbPath) {
        Write-Host "Successfully added ADB to PATH!" -ForegroundColor Green
        
        # Refresh current session
        $env:Path = $updatedPath

        # Test adb command
        $null = Get-Command adb -ErrorAction SilentlyContinue
        if ($?) {
            $adbVersion = & adb version 2>&1
            Write-Host "ADB is now accessible from command line!" -ForegroundColor Green
            Write-Host $adbVersion
        }
        else {
            Write-Warning "ADB path added but command not found. You may need to restart your terminal."
        }
    }
    else {
        throw "Failed to verify PATH update"
    }
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
