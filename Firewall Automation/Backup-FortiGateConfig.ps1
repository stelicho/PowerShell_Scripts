<#
.SYNOPSIS
    Downloads a full configuration backup from a FortiGate firewall via its REST API.

.DESCRIPTION
    Rough-draft config backup script for FortiOS's REST API (used in place
    of manually exporting from FortiGate/FortiManager). Requires an API
    token generated on the FortiGate (System > Administrators > REST API Admin).

.PARAMETER FortiGateHost
    FortiGate management IP/hostname.

.PARAMETER ApiToken
    REST API token for the FortiGate. Prompted as a secure string if not supplied.

.PARAMETER OutputPath
    Folder to save the timestamped config backup to.

.PARAMETER Port
    HTTPS management port. Default: 443.

.EXAMPLE
    .\Backup-FortiGateConfig.ps1 -FortiGateHost fw01.corp.local -OutputPath C:\FirewallBackups

.NOTES
    FortiGate management interfaces commonly present a self-signed
    certificate, so this script disables TLS certificate validation for the
    request. Install a trusted certificate on the FortiGate and remove the
    bypass before relying on this in a production/compliance context.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$FortiGateHost,

    [System.Security.SecureString]$ApiToken,

    [Parameter(Mandatory)]
    [string]$OutputPath,

    [int]$Port = 443
)

$ErrorActionPreference = 'Stop'

if (-not $ApiToken) {
    $ApiToken = Read-Host -Prompt "FortiGate REST API token for $FortiGateHost" -AsSecureString
}
$plainToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ApiToken))

if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outputFile = Join-Path $OutputPath "$FortiGateHost-$timestamp.conf"
$uri = "https://$FortiGateHost`:$Port/api/v2/monitor/system/config/backup?access_token=$plainToken"

Write-Warning "TLS certificate validation is disabled below for the FortiGate's (commonly self-signed) management certificate."

if ($PSVersionTable.PSVersion.Major -ge 6) {
    Invoke-RestMethod -Uri $uri -Method Get -OutFile $outputFile -SkipCertificateCheck
}
else {
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    Invoke-RestMethod -Uri $uri -Method Get -OutFile $outputFile
}

if (Test-Path $outputFile) {
    Write-Host "Configuration backup saved to $outputFile" -ForegroundColor Green
}
else {
    Write-Warning "Backup request completed but no file was written - check the API token and connectivity."
}
