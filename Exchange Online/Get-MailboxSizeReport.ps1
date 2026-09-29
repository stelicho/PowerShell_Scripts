<#
.SYNOPSIS
    Reports mailbox size and item count for all Exchange Online mailboxes,
    flagging anything close to its storage quota.

.DESCRIPTION
    Rough-draft mailbox capacity report using the ExchangeOnlineManagement
    module. Useful for catching mailboxes about to hit their quota before
    users start getting bounce/send errors, and for right-sizing license SKUs.

.PARAMETER WarningPct
    Flag mailboxes at or above this percentage of their prohibit-send quota. Default: 85.

.PARAMETER ReportPath
    Optional path to export the results as CSV.

.EXAMPLE
    .\Get-MailboxSizeReport.ps1 -ReportPath C:\Reports\mailbox-sizes.csv
#>

[CmdletBinding()]
param(
    [int]$WarningPct = 85,
    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'

Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline -ShowBanner:$false

$mailboxes = Get-Mailbox -ResultSize Unlimited

$report = foreach ($mbx in $mailboxes) {
    $stats = Get-MailboxStatistics -Identity $mbx.PrimarySmtpAddress
    $usedBytes = $stats.TotalItemSize.Value.ToBytes()

    $quota = $mbx.ProhibitSendQuota
    $quotaBytes = if ($quota -and $quota.ToString() -ne 'Unlimited') { $quota.Value.ToBytes() } else { $null }
    $pctUsed = if ($quotaBytes) { [math]::Round(($usedBytes / $quotaBytes) * 100, 1) } else { $null }

    [PSCustomObject]@{
        Mailbox     = $mbx.PrimarySmtpAddress
        SizeGB      = [math]::Round($usedBytes / 1GB, 2)
        ItemCount   = $stats.ItemCount
        QuotaGB     = if ($quotaBytes) { [math]::Round($quotaBytes / 1GB, 2) } else { 'Unlimited' }
        PercentUsed = $pctUsed
        NearQuota   = $null -ne $pctUsed -and $pctUsed -ge $WarningPct
    }
}

$report | Sort-Object PercentUsed -Descending | Format-Table -AutoSize

$near = $report | Where-Object NearQuota
if ($near) {
    Write-Warning "$($near.Count) mailbox(es) at or above $WarningPct% of quota."
}

if ($ReportPath) {
    $report | Export-Csv -Path $ReportPath -NoTypeInformation
    Write-Host "Report exported to $ReportPath" -ForegroundColor Green
}

Disconnect-ExchangeOnline -Confirm:$false
