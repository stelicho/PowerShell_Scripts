<#
.SYNOPSIS
    Sweeps a list of network devices to check ICMP and management-port
    reachability, with response-time reporting.

.DESCRIPTION
    Lightweight NOC-style monitoring check. Reads a list of hostnames/IPs and
    reports ping status plus TCP reachability on a management port. Useful as
    a scheduled task feeding a dashboard or alert pipeline.

.PARAMETER DeviceListPath
    Path to a text file with one hostname/IP per line, or a CSV with a Hostname column.

.PARAMETER Port
    TCP port to check for management reachability. Default: 22 (SSH).

.EXAMPLE
    .\Test-DeviceReachability.ps1 -DeviceListPath .\devices.txt

.EXAMPLE
    .\Test-DeviceReachability.ps1 -DeviceListPath .\devices.csv -Port 443
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$DeviceListPath,

    [int]$Port = 22
)

$ErrorActionPreference = 'Stop'

$raw = Get-Content -Path $DeviceListPath
if ($raw[0] -match ',') {
    $devices = ($raw | ConvertFrom-Csv).Hostname
}
else {
    $devices = $raw | Where-Object { $_.Trim() }
}

$results = foreach ($device in $devices) {
    $ping = Test-Connection -ComputerName $device -Count 2 -ErrorAction SilentlyContinue
    $pingOk = [bool]($ping | Where-Object { $_.StatusCode -eq 0 -or $_.Status -eq 'Success' })
    $avgLatency = if ($ping) { [math]::Round(($ping | Measure-Object -Property ResponseTime -Average -ErrorAction SilentlyContinue).Average, 1) } else { $null }

    $tcp = Test-NetConnection -ComputerName $device -Port $Port -WarningAction SilentlyContinue

    [PSCustomObject]@{
        Device       = $device
        PingOk       = $pingOk
        AvgLatencyMs = $avgLatency
        PortOpen     = $tcp.TcpTestSucceeded
        Port         = $Port
        Status       = if ($pingOk -and $tcp.TcpTestSucceeded) { 'Healthy' } elseif ($pingOk) { 'Ping OK, port closed' } else { 'Unreachable' }
    }
}

$results | Format-Table -AutoSize

$down = $results | Where-Object { $_.Status -ne 'Healthy' }
if ($down) {
    Write-Warning "$($down.Count) device(s) are not fully healthy."
}
