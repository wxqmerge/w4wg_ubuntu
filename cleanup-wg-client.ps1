# cleanup-wg-client.ps1 - Remove all WireGuard settings from Windows
# Run as Administrator: powershell -ExecutionPolicy Bypass -File cleanup-wg-client.ps1

Write-Host "=== WireGuard Client Cleanup ===" -ForegroundColor Cyan

# 1. Stop and disable all WireGuard tunnels
Write-Host "[1/4] Stopping WireGuard tunnels..." -ForegroundColor Yellow
$services = Get-Service -Name "Wg*" -ErrorAction SilentlyContinue
if ($services) {
    foreach ($svc in $services) {
        if ($svc.Status -eq "Running") {
            Stop-Service -Name $svc.Name -Force
            Write-Host "  Stopped: $($svc.Name)"
        }
        Set-Service -Name $svc.Name -StartupType Disabled
        Write-Host "  Disabled: $($svc.Name)"
    }
} else {
    Write-Host "  No WireGuard services found."
}
Write-Host "Done."

# 2. Remove WireGuard tunnel configs
Write-Host "[2/4] Removing tunnel configurations..." -ForegroundColor Yellow
$wgDir = "C:\Program Files\WireGuard"
if (Test-Path $wgDir) {
    $tunnels = Get-ChildItem -Path $wgDir -Filter "*.conf" -ErrorAction SilentlyContinue
    if ($tunnels) {
        foreach ($tunnel in $tunnels) {
            Remove-Item -Path $tunnel.FullName -Force
            Write-Host "  Removed: $($tunnel.Name)"
        }
    } else {
        Write-Host "  No tunnel config files found."
    }
} else {
    Write-Host "  WireGuard directory not found."
}
Write-Host "Done."

# 3. Remove WireGuard registry entries
Write-Host "[3/4] Removing registry entries..." -ForegroundColor Yellow
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\WireGuard"
if (Test-Path $regPath) {
    # Remove tunnel keys (subkeys like wg0, wg0-client, etc.)
    $tunnelKeys = Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -ne "Parameters" }
    if ($tunnelKeys) {
        foreach ($key in $tunnelKeys) {
            Remove-Item -Path $key.PSPath -Recurse -Force
            Write-Host "  Removed registry key: $($key.PSChildName)"
        }
    }
    Write-Host "  Registry cleanup complete."
} else {
    Write-Host "  No registry entries found."
}
Write-Host "Done."

# 4. Optional: Uninstall WireGuard application
Write-Host "[4/4] Uninstall WireGuard application?" -ForegroundColor Yellow
Write-Host "  (Y) Yes - Uninstall WireGuard completely"
Write-Host "  (N) No  - Keep WireGuard installed, just remove configs"
$response = Read-Host "Choose [Y/N]"

if ($response -eq "Y" -or $response -eq "y") {
    Write-Host "  Uninstalling WireGuard..."
    $packages = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*WireGuard*" }
    if ($packages) {
        foreach ($pkg in $packages) {
            if ($pkg.UninstallString) {
                $uninstallCmd = $pkg.UninstallString -replace '^"', '' -replace '"$', ''
                Start-Process -FilePath cmd.exe -ArgumentList "/c $uninstallCmd /S" -Wait -NoNewWindow
                Write-Host "  Uninstalled: $($pkg.DisplayName)"
            }
        }
    }
    # Also try removing the directory
    if (Test-Path $wgDir) {
        Remove-Item -Path $wgDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  Removed installation directory."
    }
    Write-Host "  WireGuard has been uninstalled."
} else {
    Write-Host "  WireGuard application kept. Only configs were removed."
}

Write-Host ""
Write-Host "=== Cleanup Complete ===" -ForegroundColor Green
Write-Host "All WireGuard client settings have been removed."
