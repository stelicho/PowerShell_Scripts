<#
.SYNOPSIS
    Reports on AD user accounts that haven't logged on in a configurable
    number of days, for offboarding/governance review.

.DESCRIPTION
    vCIO/governance-style hygiene report: flags stale accounts (former
    employees, contractors, service accounts left enabled) so they can be
    reviewed and disabled. Reads LastLogonTimestamp, which is replicated
    domain-wide (unlike LastLogon), so results are accurate without needing
    to query every DC.

.PARAMETER InactiveDays
    Number of days without a logon before an account is flagged. Default: 45.

.PARAMETER SearchBase
    Optional OU distinguished name to limit the search to.

.PARAMETER ReportPath
    Optional path to export the results as CSV.

.EXAMPLE
    .\Get-InactiveUserReport.ps1 -InactiveDays 60 -ReportPath C:\Reports\inactive-users.csv
#>

[CmdletBinding()]
param(
    [int]$InactiveDays = 45,
    [string]$SearchBase,
    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

$cutoffDate = (Get-Date).AddDays(-$InactiveDays)

$filterParams = @{
    Filter     = "Enabled -eq 'True'"
    Properties = 'LastLogonTimestamp', 'PasswordLastSet', 'DistinguishedName'
}
if ($SearchBase) { $filterParams.SearchBase = $SearchBase }

$staleUsers = Get-ADUser @filterParams | ForEach-Object {
    $lastLogon = if ($_.LastLogonTimestamp) { [datetime]::FromFileTime($_.LastLogonTimestamp) } else { $null }
    if (-not $lastLogon -or $lastLogon -lt $cutoffDate) {
        [PSCustomObject]@{
            SamAccountName = $_.SamAccountName
            Name           = $_.Name
            LastLogon      = $lastLogon
            DaysInactive   = if ($lastLogon) { (New-TimeSpan -Start $lastLogon -End (Get-Date)).Days } else { 'Never logged on' }
            OU             = ($_.DistinguishedName -split ',', 2)[1]
        }
    }
}

$staleUsers | Sort-Object DaysInactive -Descending | Format-Table -AutoSize

if ($ReportPath) {
    $staleUsers | Export-Csv -Path $ReportPath -NoTypeInformation
    Write-Host "Report exported to $ReportPath" -ForegroundColor Green
}
