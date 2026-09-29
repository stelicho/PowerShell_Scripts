<#
.SYNOPSIS
    Resets the common Windows Update components that cause updates to hang
    or fail to install (stuck services, corrupt SoftwareDistribution cache, etc).

.DESCRIPTION
    Classic Tier 2 desktop-support fix-it script. Stops the relevant services,
    renames the SoftwareDistribution and catroot2 folders so Windows rebuilds
    them, re-registers the BITS/WU-related DLLs, and restarts the services.

.EXAMPLE
    .\Repair-WindowsUpdateComponents.ps1
#>

[CmdletBinding(SupportsShouldProcess)]
param()

$ErrorActionPreference = 'Stop'
$services = 'wuauserv', 'cryptSvc', 'bits', 'msiserver'

function Assert-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal   = New-Object Security.Principal.WindowsPrincipal($currentUser)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "This script must be run from an elevated (Administrator) PowerShell session."
    }
}
Assert-Administrator

if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Reset Windows Update components")) {
    Write-Host "Stopping Windows Update-related services..." -ForegroundColor Cyan
    foreach ($svc in $services) {
        Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
    }

    Write-Host "Renaming SoftwareDistribution and catroot2..." -ForegroundColor Cyan
    $timestamp = Get-Date -Format 'yyyyMMddHHmmss'
    foreach ($path in "$env:WINDIR\SoftwareDistribution", "$env:WINDIR\System32\catroot2") {
        if (Test-Path $path) {
            Rename-Item -Path $path -NewName "$(Split-Path $path -Leaf).bak-$timestamp"
        }
    }

    Write-Host "Re-registering BITS/WU DLLs..." -ForegroundColor Cyan
    $dlls = 'atl.dll', 'urlmon.dll', 'mshtml.dll', 'shdocvw.dll', 'browseui.dll', 'jscript.dll',
            'vbscript.dll', 'scrrun.dll', 'msxml.dll', 'msxml3.dll', 'msxml6.dll', 'actxprxy.dll',
            'softpub.dll', 'wintrust.dll', 'dssenh.dll', 'rsaenh.dll', 'gpkcsp.dll', 'sccbase.dll',
            'slbcsp.dll', 'cryptdlg.dll', 'oleaut32.dll', 'ole32.dll', 'shell32.dll', 'initpki.dll',
            'wuapi.dll', 'wuaueng.dll', 'wuaueng1.dll', 'wucltui.dll', 'wups.dll', 'wups2.dll',
            'wuweb.dll', 'qmgr.dll', 'qmgrprxy.dll', 'wucltux.dll', 'muweb.dll', 'wuwebv.dll'

    foreach ($dll in $dlls) {
        Start-Process -FilePath 'regsvr32.exe' -ArgumentList '/s', $dll -Wait -ErrorAction SilentlyContinue
    }

    Write-Host "Restarting services..." -ForegroundColor Cyan
    foreach ($svc in $services) {
        Start-Service -Name $svc -ErrorAction SilentlyContinue
    }

    Write-Host "Windows Update components have been reset. A reboot is recommended." -ForegroundColor Green
}
