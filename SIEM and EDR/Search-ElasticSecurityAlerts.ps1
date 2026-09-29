<#
.SYNOPSIS
    Queries the Elastic Security (Kibana) detection engine alerts API for
    recent alerts and summarizes them by severity.

.DESCRIPTION
    Rough-draft SIEM triage helper. Hits Kibana's detection engine signals
    search endpoint directly via REST, since there's no first-party Elastic
    PowerShell module. Useful for a quick daily "what fired overnight" pull
    without opening the Kibana UI.

.PARAMETER KibanaUrl
    Base URL of the Kibana instance, e.g. "https://elastic.corp.local:5601".

.PARAMETER ApiKey
    Elastic API key (base64 "id:key" format) used for authentication.

.PARAMETER HoursBack
    How far back to search for alerts. Default: 24.

.PARAMETER MinSeverity
    Minimum severity to include: low, medium, high, critical. Default: medium.

.EXAMPLE
    .\Search-ElasticSecurityAlerts.ps1 -KibanaUrl https://elastic.corp.local:5601 -ApiKey $apiKey -MinSeverity high
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$KibanaUrl,

    [Parameter(Mandatory)]
    [string]$ApiKey,

    [int]$HoursBack = 24,

    [ValidateSet('low', 'medium', 'high', 'critical')]
    [string]$MinSeverity = 'medium'
)

$ErrorActionPreference = 'Stop'

$severityOrder = @{ low = 0; medium = 1; high = 2; critical = 3 }
$minRank = $severityOrder[$MinSeverity]

$headers = @{
    Authorization  = "ApiKey $ApiKey"
    'kbn-xsrf'     = 'true'
    'Content-Type' = 'application/json'
}

$body = @{
    query = @{
        bool = @{
            filter = @(
                @{ range = @{ '@timestamp' = @{ gte = "now-$HoursBack`h" } } }
            )
        }
    }
    size = 200
    sort = @(@{ '@timestamp' = 'desc' })
} | ConvertTo-Json -Depth 6

$uri = "$KibanaUrl/api/detection_engine/signals/search"
$response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body

$alerts = $response.hits.hits | ForEach-Object {
    [PSCustomObject]@{
        Time     = $_._source.'@timestamp'
        Rule     = $_._source.signal.rule.name
        Severity = $_._source.signal.rule.severity
        Host     = $_._source.host.name
        User     = $_._source.user.name
    }
} | Where-Object { $severityOrder[$_.Severity] -ge $minRank }

$alerts | Sort-Object Time -Descending | Format-Table -AutoSize

Write-Host "`n$($alerts.Count) alert(s) at '$MinSeverity' severity or above in the last $HoursBack hour(s)." -ForegroundColor Cyan
$alerts | Group-Object Severity | Sort-Object Name | ForEach-Object {
    Write-Host "  $($_.Name): $($_.Count)" -ForegroundColor Yellow
}
