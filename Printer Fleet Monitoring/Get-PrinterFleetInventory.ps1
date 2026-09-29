<#
.SYNOPSIS
    Builds an inventory of network printers/MFCs from a list of IPs or
    hostnames, using SNMP to pull description, serial number, and page count.

.DESCRIPTION
    Rough-draft printer fleet inventory tool. Shells out to the Net-SNMP
    "snmpget" utility (commonly installed alongside network diagnostic tools
    like Wireshark/NMAP) to query standard Printer-MIB OIDs, since Windows
    PowerShell has no built-in SNMP client. Swap in a native SNMP module if
    snmpget.exe isn't available in your environment.

.PARAMETER DeviceListPath
    Path to a text file with one printer IP/hostname per line.

.PARAMETER Community
    SNMP v2c community string. Default: "public".

.PARAMETER ReportPath
    Optional path to export the inventory as CSV.

.EXAMPLE
    .\Get-PrinterFleetInventory.ps1 -DeviceListPath .\printers.txt -ReportPath C:\Reports\printer-inventory.csv
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$DeviceListPath,

    [string]$Community = 'public',

    [string]$ReportPath
)

$ErrorActionPreference = 'Continue'

if (-not (Get-Command snmpget -ErrorAction SilentlyContinue)) {
    throw "snmpget.exe (Net-SNMP tools) was not found on PATH. Install the Net-SNMP utilities or swap in an SNMP PowerShell module."
}

# Standard Printer-MIB / SNMPv2-MIB OIDs
$oids = @{
    Description        = '1.3.6.1.2.1.1.1.0'
    SerialNumber        = '1.3.6.1.2.1.43.5.1.1.17.1'
    LifetimePageCount   = '1.3.6.1.2.1.43.10.2.1.4.1.1'
}

function Get-SnmpValue {
    param([string]$Target, [string]$Community, [string]$Oid)
    $raw = snmpget -v2c -c $Community -O qv $Target $Oid 2>$null
    if ($LASTEXITCODE -eq 0) { return ($raw -join ' ').Trim() }
    return $null
}

$devices = Get-Content -Path $DeviceListPath | Where-Object { $_.Trim() }

$inventory = foreach ($device in $devices) {
    [PSCustomObject]@{
        Device       = $device
        Description  = Get-SnmpValue -Target $device -Community $Community -Oid $oids.Description
        SerialNumber = Get-SnmpValue -Target $device -Community $Community -Oid $oids.SerialNumber
        PageCount    = Get-SnmpValue -Target $device -Community $Community -Oid $oids.LifetimePageCount
    }
}

$inventory | Format-Table -AutoSize

if ($ReportPath) {
    $inventory | Export-Csv -Path $ReportPath -NoTypeInformation
    Write-Host "Inventory exported to $ReportPath" -ForegroundColor Green
}
