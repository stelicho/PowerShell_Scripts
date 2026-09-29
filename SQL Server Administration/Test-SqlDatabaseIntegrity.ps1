<#
.SYNOPSIS
    Runs DBCC CHECKDB against one or more SQL Server databases and reports
    any integrity errors found.

.DESCRIPTION
    Rough-draft database health check. Useful as a scheduled maintenance
    task ahead of/alongside backups, to catch corruption early rather than
    discovering it during a restore.

.PARAMETER ServerInstance
    SQL Server instance to connect to.

.PARAMETER Database
    One or more database names to check. Defaults to all user databases if not specified.

.PARAMETER ReportPath
    Optional path to export the results as CSV.

.EXAMPLE
    .\Test-SqlDatabaseIntegrity.ps1 -ServerInstance SQLSRV01
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ServerInstance,

    [string[]]$Database,

    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'
Import-Module SqlServer

if (-not $Database) {
    $Database = (Invoke-Sqlcmd -ServerInstance $ServerInstance -Query "SELECT name FROM sys.databases WHERE database_id > 4 AND state = 0").name
}

$results = foreach ($db in $Database) {
    Write-Host "Checking $db..." -ForegroundColor Cyan
    try {
        Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $db -Query "DBCC CHECKDB('$db') WITH NO_INFOMSGS, ALL_ERRORMSGS" -QueryTimeout 0 -ErrorAction Stop | Out-Null
        [PSCustomObject]@{ Database = $db; Status = 'Clean'; Details = $null }
    }
    catch {
        Write-Warning "$db reported integrity errors: $($_.Exception.Message)"
        [PSCustomObject]@{ Database = $db; Status = 'Errors Found'; Details = $_.Exception.Message }
    }
}

$results | Format-Table -AutoSize

if ($ReportPath) {
    $results | Export-Csv -Path $ReportPath -NoTypeInformation
    Write-Host "Report exported to $ReportPath" -ForegroundColor Green
}
