<#
.SYNOPSIS
    Reports the status of Veeam Backup & Replication jobs from the last N
    hours and flags any failures/warnings for follow-up.

.DESCRIPTION
    Rough-draft backup monitoring script for environments running Veeam
    Backup & Replication. Requires the Veeam.Backup.PowerShell module, which
    ships alongside the Veeam console/server install.

.PARAMETER HoursBack
    How far back to look for completed job sessions. Default: 24.

.PARAMETER ReportPath
    Optional path to export the results as CSV.

.EXAMPLE
    .\Get-VeeamJobStatusReport.ps1

.EXAMPLE
    .\Get-VeeamJobStatusReport.ps1 -HoursBack 48 -ReportPath C:\Reports\veeam-status.csv
#>

[CmdletBinding()]
param(
    [int]$HoursBack = 24,
    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable -Name Veeam.Backup.PowerShell)) {
    throw "The Veeam.Backup.PowerShell module was not found. Run this on a server with the Veeam Backup & Replication console installed."
}
Import-Module Veeam.Backup.PowerShell

$cutoff = (Get-Date).AddHours(-$HoursBack)
$sessions = Get-VBRBackupSession | Where-Object { $_.EndTime -ge $cutoff -or $_.CreationTime -ge $cutoff }

$report = $sessions | Select-Object `
    @{N = 'JobName'; E = { $_.JobName } },
    @{N = 'Result'; E = { $_.Result } },
    @{N = 'StartTime'; E = { $_.CreationTime } },
    @{N = 'EndTime'; E = { $_.EndTime } },
    @{N = 'DurationMin'; E = { [math]::Round(($_.EndTime - $_.CreationTime).TotalMinutes, 1) } }

$report | Sort-Object StartTime -Descending | Format-Table -AutoSize

$problems = $report | Where-Object { $_.Result -ne 'Success' }
if ($problems) {
    Write-Warning "$($problems.Count) job session(s) did not complete successfully in the last $HoursBack hour(s):"
    $problems | Format-Table JobName, Result, StartTime -AutoSize
}
else {
    Write-Host "All backup jobs completed successfully in the last $HoursBack hour(s)." -ForegroundColor Green
}

if ($ReportPath) {
    $report | Export-Csv -Path $ReportPath -NoTypeInformation
    Write-Host "Report exported to $ReportPath" -ForegroundColor Cyan
}
