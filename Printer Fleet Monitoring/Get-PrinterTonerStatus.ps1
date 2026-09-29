<#
.SYNOPSIS
    Polls a list of network printers/MFCs via SNMP for toner/consumable
    levels and flags any running low.

.DESCRIPTION
    Companion to Get-PrinterFleetInventory.ps1. Queries the standard
    Printer-MIB supplies table for description, current level, and max
    capacity per consumable (black/color toner, drums, etc.), reports
    percent remaining, and flags anything under a warning threshold.

.PARAMETER DeviceListPath
    Path to a text file with one printer IP/hostname per line.

.PARAMETER Community
    SNMP v2c community string. Default: "public".

.PARAMETER WarningPct
    Flag consumables at or below this percentage remaining. Default: 15.

.EXAMPLE
    .\Get-PrinterTonerStatus.ps1 -DeviceListPath .\printers.txt -WarningPct 20
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$DeviceListPath,

    [string]$Community = 'public',

    [int]$WarningPct = 15
)

$ErrorActionPreference = 'Continue'

if (-not (Get-Command snmpwalk -ErrorAction SilentlyContinue)) {
    throw "snmpwalk.exe (Net-SNMP tools) was not found on PATH. Install the Net-SNMP utilities or swap in an SNMP PowerShell module."
}

# Printer-MIB supplies table: description / current level / max capacity
$supplyDescOid  = '1.3.6.1.2.1.43.11.1.1.6.1'
$supplyLevelOid = '1.3.6.1.2.1.43.11.1.1.9.1'
$supplyMaxOid   = '1.3.6.1.2.1.43.11.1.1.8.1'

$devices = Get-Content -Path $DeviceListPath | Where-Object { $_.Trim() }
$results = @()

foreach ($device in $devices) {
    $descriptions = snmpwalk -v2c -c $Community -O qv $device $supplyDescOid 2>$null
    $levels       = snmpwalk -v2c -c $Community -O qv $device $supplyLevelOid 2>$null
    $maximums     = snmpwalk -v2c -c $Community -O qv $device $supplyMaxOid 2>$null

    if (-not $descriptions) {
        $results += [PSCustomObject]@{ Device = $device; Supply = 'Unreachable'; PercentRemaining = $null; Low = $true }
        continue
    }

    for ($i = 0; $i -lt $descriptions.Count; $i++) {
        $level = [double]($levels[$i] -replace '[^\d.-]')
        $max   = [double]($maximums[$i] -replace '[^\d.-]')
        $pct   = if ($max -gt 0) { [math]::Round(($level / $max) * 100, 1) } else { $null }

        $results += [PSCustomObject]@{
            Device           = $device
            Supply           = $descriptions[$i].Trim('"')
            PercentRemaining = $pct
            Low              = $null -ne $pct -and $pct -le $WarningPct
        }
    }
}

$results | Format-Table -AutoSize

$low = $results | Where-Object Low
if ($low) {
    Write-Warning "$($low.Count) consumable(s) at or below $WarningPct%:"
    $low | Format-Table Device, Supply, PercentRemaining -AutoSize
}
