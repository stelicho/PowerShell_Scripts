<#
.SYNOPSIS
    Runs a full (or differential) backup of one or more SQL Server databases
    and prunes old backup files past a retention window.

.DESCRIPTION
    Rough-draft SQL Server maintenance script using the SqlServer module's
    Backup-SqlDatabase cmdlet. Writes compressed .bak files per database to
    a dated subfolder and removes backups older than the retention period.

.PARAMETER ServerInstance
    SQL Server instance to connect to, e.g. "SQLSRV01" or "SQLSRV01\INSTANCE".

.PARAMETER Database
    One or more database names to back up. Defaults to all user databases
    (excludes system databases) if not specified.

.PARAMETER BackupPath
    Root folder to write backup files to. A dated subfolder is created per run.

.PARAMETER BackupType
    Full or Differential. Default: Full.

.PARAMETER RetentionDays
    Backup files older than this many days are deleted after the run. Default: 14.

.EXAMPLE
    .\Backup-SqlDatabase.ps1 -ServerInstance SQLSRV01 -BackupPath D:\SQLBackups

.EXAMPLE
    .\Backup-SqlDatabase.ps1 -ServerInstance SQLSRV01 -Database AthenaOne -BackupType Differential -BackupPath D:\SQLBackups
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$ServerInstance,

    [string[]]$Database,

    [Parameter(Mandatory)]
    [string]$BackupPath,

    [ValidateSet('Full', 'Differential')]
    [string]$BackupType = 'Full',

    [int]$RetentionDays = 14
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable -Name SqlServer)) {
    throw "The SqlServer module is required. Install it with: Install-Module SqlServer -Scope CurrentUser"
}
Import-Module SqlServer

if (-not $Database) {
    $Database = (Invoke-Sqlcmd -ServerInstance $ServerInstance -Query "SELECT name FROM sys.databases WHERE database_id > 4 AND state = 0").name
}

$dateFolder = Join-Path $BackupPath (Get-Date -Format 'yyyy-MM-dd')
if (-not (Test-Path $dateFolder)) {
    New-Item -Path $dateFolder -ItemType Directory -Force | Out-Null
}

$results = foreach ($db in $Database) {
    $extension = if ($BackupType -eq 'Full') { 'bak' } else { 'dif' }
    $backupFile = Join-Path $dateFolder "$db-$BackupType-$(Get-Date -Format 'HHmmss').$extension"

    if ($PSCmdlet.ShouldProcess($db, "$BackupType backup to $backupFile")) {
        try {
            Backup-SqlDatabase -ServerInstance $ServerInstance -Database $db -BackupFile $backupFile -BackupAction $BackupType -CompressionOption On
            Write-Host "Backed up $db -> $backupFile" -ForegroundColor Green
            [PSCustomObject]@{ Database = $db; Status = 'Success'; File = $backupFile }
        }
        catch {
            Write-Warning "Failed to back up $db : $($_.Exception.Message)"
            [PSCustomObject]@{ Database = $db; Status = "Failed: $($_.Exception.Message)"; File = $null }
        }
    }
}

$results | Format-Table -AutoSize

Write-Host "Pruning backups older than $RetentionDays day(s) in $BackupPath..." -ForegroundColor Cyan
Get-ChildItem -Path $BackupPath -Recurse -Include *.bak, *.dif -File |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$RetentionDays) } |
    Remove-Item -Force
