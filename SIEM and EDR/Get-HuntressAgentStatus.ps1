<#
.SYNOPSIS
    Pulls agent (endpoint) status from the Huntress managed EDR API and
    flags agents that haven't checked in recently.

.DESCRIPTION
    Rough-draft EDR coverage-check script. The Huntress API uses HTTP basic
    auth with an account API key/secret pair (generated under Account
    Settings > API Credentials). Useful as a periodic sanity check that
    every endpoint that should be reporting to Huntress actually is.

.PARAMETER ApiKey
.PARAMETER ApiSecret
    Huntress API key/secret pair.

.PARAMETER OfflineThresholdHours
    Flag agents that haven't checked in within this many hours. Default: 24.

.PARAMETER ReportPath
    Optional path to export the results as CSV.

.EXAMPLE
    .\Get-HuntressAgentStatus.ps1 -ApiKey $key -ApiSecret $secret -ReportPath C:\Reports\huntress-agents.csv
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ApiKey,

    [Parameter(Mandatory)]
    [string]$ApiSecret,

    [int]$OfflineThresholdHours = 24,

    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'

$pair = "$ApiKey`:$ApiSecret"
$basicAuth = [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
$headers = @{ Authorization = "Basic $basicAuth" }

$agents = @()
$page = 1

do {
    $response = Invoke-RestMethod -Uri "https://api.huntress.io/v1/agents?page=$page" -Headers $headers -Method Get
    $agents += $response.agents
    $page++
} while ($response.agents.Count -gt 0 -and $page -le $response.pagination_total_pages)

$cutoff = (Get-Date).AddHours(-$OfflineThresholdHours)

$report = $agents | Select-Object `
    @{N = 'Hostname'; E = { $_.hostname } },
    @{N = 'OS'; E = { $_.os } },
    @{N = 'Version'; E = { $_.version } },
    @{N = 'LastSeenAt'; E = { $_.last_seen_at } },
    @{N = 'Offline'; E = { [datetime]$_.last_seen_at -lt $cutoff } }

$report | Sort-Object Offline -Descending | Format-Table -AutoSize

$offline = $report | Where-Object Offline
if ($offline) {
    Write-Warning "$($offline.Count) agent(s) haven't checked in within $OfflineThresholdHours hour(s)."
}

if ($ReportPath) {
    $report | Export-Csv -Path $ReportPath -NoTypeInformation
    Write-Host "Report exported to $ReportPath" -ForegroundColor Green
}
