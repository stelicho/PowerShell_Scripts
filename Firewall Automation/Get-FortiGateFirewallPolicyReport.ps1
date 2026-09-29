<#
.SYNOPSIS
    Pulls the firewall policy table from a FortiGate via its REST API and
    exports a readable report (source/destination, service, action, logging).

.DESCRIPTION
    Rough-draft firewall rule documentation/audit script. Useful ahead of a
    PCI DSS-style rule review, or just to get an exportable view of policies
    without clicking through the GUI page by page.

.PARAMETER FortiGateHost
    FortiGate management IP/hostname.

.PARAMETER ApiToken
    REST API token for the FortiGate. Prompted as a secure string if not supplied.

.PARAMETER Port
    HTTPS management port. Default: 443.

.PARAMETER ReportPath
    Optional path to export the policy report as CSV.

.EXAMPLE
    .\Get-FortiGateFirewallPolicyReport.ps1 -FortiGateHost fw01.corp.local -ReportPath C:\Reports\fw-policies.csv

.NOTES
    Disables TLS certificate validation for the FortiGate's commonly
    self-signed management certificate - see Backup-FortiGateConfig.ps1 for
    the same caveat.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$FortiGateHost,

    [System.Security.SecureString]$ApiToken,

    [int]$Port = 443,

    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'

if (-not $ApiToken) {
    $ApiToken = Read-Host -Prompt "FortiGate REST API token for $FortiGateHost" -AsSecureString
}
$plainToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ApiToken))

$uri = "https://$FortiGateHost`:$Port/api/v2/cmdb/firewall/policy?access_token=$plainToken"

Write-Warning "TLS certificate validation is disabled below for the FortiGate's (commonly self-signed) management certificate."

if ($PSVersionTable.PSVersion.Major -ge 6) {
    $response = Invoke-RestMethod -Uri $uri -Method Get -SkipCertificateCheck
}
else {
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    $response = Invoke-RestMethod -Uri $uri -Method Get
}

$report = $response.results | Select-Object `
    @{N = 'PolicyId'; E = { $_.policyid } },
    @{N = 'Name'; E = { $_.name } },
    @{N = 'Source'; E = { ($_.srcaddr | Select-Object -ExpandProperty name) -join ', ' } },
    @{N = 'Destination'; E = { ($_.dstaddr | Select-Object -ExpandProperty name) -join ', ' } },
    @{N = 'Service'; E = { ($_.service | Select-Object -ExpandProperty name) -join ', ' } },
    @{N = 'Action'; E = { $_.action } },
    @{N = 'LogTraffic'; E = { $_.logtraffic } },
    @{N = 'Status'; E = { $_.status } }

$report | Format-Table -AutoSize

if ($ReportPath) {
    $report | Export-Csv -Path $ReportPath -NoTypeInformation
    Write-Host "Report exported to $ReportPath" -ForegroundColor Green
}
