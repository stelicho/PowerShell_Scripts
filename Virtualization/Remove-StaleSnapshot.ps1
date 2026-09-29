<#
.SYNOPSIS
    Finds and optionally removes Hyper-V checkpoints (snapshots) older than a
    given age, to reclaim storage and avoid the performance hit of long
    checkpoint chains.

.DESCRIPTION
    Companion cleanup script to Get-VMHealthReport.ps1 (which covers VMware).
    Hyper-V checkpoints left in place for extended periods bloat differencing
    disks and slow down the parent VM; this script reports on (and can
    remove) checkpoints past a configurable age threshold.

.PARAMETER MaxAgeDays
    Checkpoints older than this many days are flagged/removed. Default: 7.

.PARAMETER VMName
    Optional list of VM names to limit the scan to. Defaults to all VMs on the host.

.PARAMETER Remove
    If specified, removes the flagged checkpoints instead of just reporting them.

.EXAMPLE
    .\Remove-StaleSnapshot.ps1 -MaxAgeDays 14

.EXAMPLE
    .\Remove-StaleSnapshot.ps1 -VMName LAB-DC01 -Remove
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [int]$MaxAgeDays = 7,
    [string[]]$VMName,
    [switch]$Remove
)

$ErrorActionPreference = 'Stop'
$cutoff = (Get-Date).AddDays(-$MaxAgeDays)

$vms = if ($VMName) { Get-VM -Name $VMName } else { Get-VM }

$stale = foreach ($vm in $vms) {
    Get-VMSnapshot -VMName $vm.Name | Where-Object { $_.CreationTime -lt $cutoff } | Select-Object VMName, Name, CreationTime,
        @{N = 'AgeDays'; E = { (New-TimeSpan -Start $_.CreationTime -End (Get-Date)).Days } }
}

if (-not $stale) {
    Write-Host "No checkpoints older than $MaxAgeDays day(s) found." -ForegroundColor Green
    return
}

$stale | Format-Table -AutoSize

if ($Remove) {
    foreach ($snap in $stale) {
        if ($PSCmdlet.ShouldProcess("$($snap.VMName) - $($snap.Name)", "Remove checkpoint")) {
            Get-VMSnapshot -VMName $snap.VMName -Name $snap.Name | Remove-VMSnapshot
            Write-Host "Removed checkpoint '$($snap.Name)' from $($snap.VMName)." -ForegroundColor Green
        }
    }
}
else {
    Write-Host "$($stale.Count) stale checkpoint(s) found. Re-run with -Remove to delete them." -ForegroundColor Yellow
}
