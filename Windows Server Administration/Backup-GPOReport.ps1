<#
.SYNOPSIS
    Backs up all Group Policy Objects in the domain and generates an HTML
    settings report for each, for change tracking and disaster recovery.

.DESCRIPTION
    Rough-draft GPO documentation/backup script. Exports every GPO to a
    timestamped backup folder (usable with Restore-GPO) and writes a
    human-readable HTML report of each GPO's settings alongside it, so
    changes can be diffed over time or referenced during an audit.

.PARAMETER BackupRoot
    Root folder to store dated GPO backups and reports in.

.PARAMETER DomainName
    AD domain to back up GPOs from. Defaults to the current domain.

.EXAMPLE
    .\Backup-GPOReport.ps1 -BackupRoot "D:\GPOBackups"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$BackupRoot,

    [string]$DomainName = (Get-ADDomain).DNSRoot
)

$ErrorActionPreference = 'Stop'
Import-Module GroupPolicy
Import-Module ActiveDirectory

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupFolder = Join-Path $BackupRoot $timestamp
New-Item -Path $backupFolder -ItemType Directory -Force | Out-Null

$gpos = Get-GPO -All -Domain $DomainName
Write-Host "Backing up $($gpos.Count) GPO(s) from '$DomainName' to $backupFolder..." -ForegroundColor Cyan

$results = foreach ($gpo in $gpos) {
    try {
        Backup-GPO -Guid $gpo.Id -Path $backupFolder -Domain $DomainName | Out-Null
        $reportFile = Join-Path $backupFolder "$($gpo.DisplayName -replace '[\\/:*?"<>|]', '_').html"
        Get-GPOReport -Guid $gpo.Id -ReportType Html -Path $reportFile -Domain $DomainName

        [PSCustomObject]@{ GPO = $gpo.DisplayName; Status = 'Backed up'; ReportPath = $reportFile }
    }
    catch {
        [PSCustomObject]@{ GPO = $gpo.DisplayName; Status = "Failed: $($_.Exception.Message)"; ReportPath = $null }
    }
}

$results | Format-Table -AutoSize
Write-Host "GPO backup and reporting complete. Restore any GPO with: Restore-GPO -Guid <id> -Path '$backupFolder'" -ForegroundColor Green
