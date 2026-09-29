<#
.SYNOPSIS
    Silently installs a standard bundle of software on a new/rebuilt Windows
    workstation using winget.

.DESCRIPTION
    Rough-draft new-PC provisioning script. Reads a list of winget package IDs
    (defaults to a common helpdesk bundle) and installs them silently, logging
    success/failure per package. Intended to run as part of imaging/deployment
    (e.g. via RMM script deployment or an Autopilot ESP script).

.PARAMETER PackageId
    One or more winget package IDs to install. Defaults to a starter bundle.

.EXAMPLE
    .\Install-StandardSoftwareBundle.ps1

.EXAMPLE
    .\Install-StandardSoftwareBundle.ps1 -PackageId "Google.Chrome", "Zoom.Zoom"
#>

[CmdletBinding()]
param(
    [string[]]$PackageId = @(
        'Google.Chrome',
        'Adobe.Acrobat.Reader.64-bit',
        'Zoom.Zoom',
        '7zip.7zip',
        'Notepad++.Notepad++'
    )
)

$ErrorActionPreference = 'Continue'

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget was not found on this system. Install the App Installer package from the Microsoft Store first."
}

$results = foreach ($id in $PackageId) {
    Write-Host "Installing $id..." -ForegroundColor Cyan
    winget install --id $id --silent --accept-package-agreements --accept-source-agreements | Out-Null
    $success = $LASTEXITCODE -eq 0

    [PSCustomObject]@{
        PackageId = $id
        Success   = $success
    }

    if ($success) {
        Write-Host "  Installed $id." -ForegroundColor Green
    }
    else {
        Write-Warning "  Failed to install $id (exit code $LASTEXITCODE)."
    }
}

$results | Format-Table -AutoSize
