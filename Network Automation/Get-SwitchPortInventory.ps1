<#
.SYNOPSIS
    SSHes into a Cisco switch and builds a port-by-port inventory: status,
    VLAN, speed/duplex, and the connected MAC address(es).

.DESCRIPTION
    Rough-draft port inventory tool for switch auditing/documentation. Parses
    the output of "show interface status" and "show mac address-table" over
    an SSH session opened with Posh-SSH.

.PARAMETER Hostname
    Switch management hostname or IP.

.PARAMETER Credential
    SSH credential. Prompted if not supplied.

.PARAMETER OutputCsvPath
    Optional path to export the combined port inventory as CSV.

.EXAMPLE
    .\Get-SwitchPortInventory.ps1 -Hostname access-sw12.corp.local -OutputCsvPath .\sw12-ports.csv
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Hostname,

    [System.Management.Automation.PSCredential]$Credential,

    [string]$OutputCsvPath
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable -Name Posh-SSH)) {
    throw "The Posh-SSH module is required. Install it with: Install-Module Posh-SSH -Scope CurrentUser"
}
Import-Module Posh-SSH

if (-not $Credential) {
    $Credential = Get-Credential -Message "SSH credentials for $Hostname"
}

$session = New-SSHSession -ComputerName $Hostname -Credential $Credential -AcceptKey -ErrorAction Stop
$stream  = New-SSHShellStream -SSHSession $session

function Invoke-SwitchCommand {
    param([string]$Command)
    $stream.WriteLine($Command)
    Start-Sleep -Seconds 2
    return $stream.Read()
}

Invoke-SwitchCommand 'terminal length 0' | Out-Null
$statusOutput = Invoke-SwitchCommand 'show interface status'
$macOutput    = Invoke-SwitchCommand 'show mac address-table'

Remove-SSHSession -SSHSession $session | Out-Null

# --- Parse "show interface status" (Port  Name  Status  Vlan  Duplex  Speed  Type) ---
$ports = @()
foreach ($line in ($statusOutput -split "`n")) {
    if ($line -match '^(?<Port>\S+)\s+(?<Name>.{0,20})\s+(?<Status>connected|notconnect|disabled|err-disabled)\s+(?<Vlan>\S+)\s+(?<Duplex>\S+)\s+(?<Speed>\S+)\s+(?<Type>.+)$') {
        $ports += [PSCustomObject]@{
            Port         = $Matches.Port
            Status       = $Matches.Status
            Vlan         = $Matches.Vlan
            Duplex       = $Matches.Duplex
            Speed        = $Matches.Speed
            Type         = $Matches.Type.Trim()
            MacAddresses = @()
        }
    }
}

# --- Parse "show mac address-table" and map MACs to ports ---
foreach ($line in ($macOutput -split "`n")) {
    if ($line -match '(?<Vlan>\d+)\s+(?<Mac>[0-9a-fA-F.:]{12,17})\s+\S+\s+(?<Port>\S+)$') {
        $matchPort = $ports | Where-Object { $_.Port -eq $Matches.Port }
        if ($matchPort) {
            $matchPort.MacAddresses += $Matches.Mac
        }
    }
}

$report = $ports | Select-Object Port, Status, Vlan, Duplex, Speed, Type,
    @{N = 'MacCount'; E = { $_.MacAddresses.Count } },
    @{N = 'MacAddresses'; E = { $_.MacAddresses -join ', ' } }

$report | Format-Table -AutoSize

if ($OutputCsvPath) {
    $report | Export-Csv -Path $OutputCsvPath -NoTypeInformation
    Write-Host "Inventory exported to $OutputCsvPath" -ForegroundColor Green
}
