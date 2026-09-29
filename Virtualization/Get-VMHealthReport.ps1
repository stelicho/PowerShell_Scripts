<#
.SYNOPSIS
    Produces a health report for a VMware vSphere environment: VM inventory,
    stale snapshots, datastore capacity, and host/cluster HA-DRS status.

.DESCRIPTION
    Rough-draft vSphere health/inventory report using VMware PowerCLI. Useful as
    a recurring check for stale snapshots eating datastore space and hosts/clusters
    that have drifted out of a healthy HA/DRS state.

.PARAMETER VCenterServer
    FQDN or IP of the vCenter server to connect to.

.PARAMETER Credential
    Credential for vCenter. Prompted if not supplied.

.PARAMETER SnapshotAgeWarningDays
    Snapshots older than this many days are flagged in the report. Default: 3.

.PARAMETER ReportPath
    Optional path to export the VM inventory as CSV.

.EXAMPLE
    .\Get-VMHealthReport.ps1 -VCenterServer vcenter.corp.local -ReportPath C:\Reports\vm-health.csv
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$VCenterServer,

    [System.Management.Automation.PSCredential]$Credential,

    [int]$SnapshotAgeWarningDays = 3,

    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable -Name VMware.PowerCLI)) {
    throw "VMware PowerCLI is required. Install it with: Install-Module VMware.PowerCLI -Scope CurrentUser"
}
Import-Module VMware.PowerCLI

Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -ParticipateInCeip $false -Confirm:$false | Out-Null

if (-not $Credential) {
    $Credential = Get-Credential -Message "Credentials for $VCenterServer"
}

Connect-VIServer -Server $VCenterServer -Credential $Credential | Out-Null

# --- Cluster HA/DRS summary ---
Write-Host "`n== Cluster HA/DRS Status ==" -ForegroundColor Cyan
Get-Cluster | Select-Object Name, HAEnabled, HAFailoverLevel, DrsEnabled, DrsAutomationLevel | Format-Table -AutoSize

# --- Host status ---
Write-Host "`n== Host Status ==" -ForegroundColor Cyan
Get-VMHost | Select-Object Name, ConnectionState, PowerState,
    @{N = 'CPU Usage %'; E = { [math]::Round(($_.CpuUsageMhz / $_.CpuTotalMhz) * 100, 1) } } |
    Format-Table -AutoSize

# --- Datastore capacity ---
Write-Host "`n== Datastore Capacity ==" -ForegroundColor Cyan
Get-Datastore | Select-Object Name,
    @{N = 'CapacityGB'; E = { [math]::Round($_.CapacityGB, 1) } },
    @{N = 'FreeGB'; E = { [math]::Round($_.FreeSpaceGB, 1) } },
    @{N = 'FreePct'; E = { [math]::Round(($_.FreeSpaceGB / $_.CapacityGB) * 100, 1) } } |
    Format-Table -AutoSize

# --- VM inventory + stale snapshots ---
$vmReport = foreach ($vm in Get-VM) {
    $snapshots = Get-Snapshot -VM $vm -ErrorAction SilentlyContinue
    $oldestSnapshot = $snapshots | Sort-Object Created | Select-Object -First 1
    $snapshotAgeDays = if ($oldestSnapshot) { (New-TimeSpan -Start $oldestSnapshot.Created -End (Get-Date)).Days } else { 0 }

    [PSCustomObject]@{
        VM                 = $vm.Name
        PowerState         = $vm.PowerState
        Host               = $vm.VMHost.Name
        NumCPU             = $vm.NumCpu
        MemoryGB           = $vm.MemoryGB
        SnapshotCount      = $snapshots.Count
        OldestSnapshotDays = $snapshotAgeDays
        NeedsAttention     = $snapshotAgeDays -ge $SnapshotAgeWarningDays
    }
}

Write-Host "`n== VM Inventory ==" -ForegroundColor Cyan
$vmReport | Format-Table -AutoSize

$stale = $vmReport | Where-Object NeedsAttention
if ($stale) {
    Write-Warning "$($stale.Count) VM(s) have snapshots older than $SnapshotAgeWarningDays day(s)."
}

if ($ReportPath) {
    $vmReport | Export-Csv -Path $ReportPath -NoTypeInformation
    Write-Host "`nReport exported to $ReportPath" -ForegroundColor Green
}

Disconnect-VIServer -Server $VCenterServer -Confirm:$false
