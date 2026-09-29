<#
.SYNOPSIS
    Tracks a simple daily LTO tape rotation schedule and logs each day's
    tape usage, flagging tapes that are overdue for off-site rotation.

.DESCRIPTION
    Rough-draft companion to disk-based backup jobs for environments still
    running LTO tape as a long-term/off-site retention tier. Cycles through
    a configured list of tape labels (e.g. a Mon-Thu daily set plus weekly/
    monthly GFS tapes), logs which tape is due today, and warns if a tape
    has been in continuous use longer than the configured off-site interval.

.PARAMETER TapeLabels
    Ordered list of tape labels in the rotation, e.g. "MON","TUE","WED","THU".

.PARAMETER LogPath
    Path to the CSV rotation log. Created (with just a header row) if it doesn't exist.

.PARAMETER OffsiteIntervalDays
    Warn if the same tape label hasn't had an "Offsite" entry logged within
    this many days. Default: 7.

.EXAMPLE
    .\Update-TapeRotationLog.ps1 -TapeLabels "MON","TUE","WED","THU","FRI-WK1" -LogPath C:\Backups\tape-rotation.csv
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string[]]$TapeLabels,

    [Parameter(Mandatory)]
    [string]$LogPath,

    [int]$OffsiteIntervalDays = 7
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $LogPath)) {
    "Date,TapeLabel,Status" | Set-Content -Path $LogPath
}

$log = Import-Csv -Path $LogPath
$dayIndex = [int](Get-Date -UFormat %j) % $TapeLabels.Count
$todaysTape = $TapeLabels[$dayIndex]

[PSCustomObject]@{
    Date      = (Get-Date -Format 'yyyy-MM-dd')
    TapeLabel = $todaysTape
    Status    = 'In Use'
} | Export-Csv -Path $LogPath -NoTypeInformation -Append

Write-Host "Today's tape: $todaysTape (logged to $LogPath)" -ForegroundColor Cyan

$lastOffsite = $log | Where-Object { $_.TapeLabel -eq $todaysTape -and $_.Status -eq 'Offsite' } |
    Sort-Object Date -Descending | Select-Object -First 1

if ($lastOffsite) {
    $daysSince = (New-TimeSpan -Start ([datetime]$lastOffsite.Date) -End (Get-Date)).Days
    if ($daysSince -gt $OffsiteIntervalDays) {
        Write-Warning "Tape '$todaysTape' hasn't been rotated off-site in $daysSince day(s) (threshold: $OffsiteIntervalDays)."
    }
}
else {
    Write-Warning "No off-site rotation has ever been logged for tape '$todaysTape'."
}
