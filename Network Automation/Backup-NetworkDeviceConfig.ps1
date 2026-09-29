<#
.SYNOPSIS
    Connects to a list of network devices over SSH and backs up their running configuration.

.DESCRIPTION
    Lightweight, vendor-agnostic config backup tool in the spirit of Netmiko/Swiftmiko-style
    SSH automation. Uses the Posh-SSH module to open a session, issue the appropriate
    "show running-config" command for each device's platform, and save the output to a
    timestamped file per device.

    Ships with Cisco IOS-XE, NX-OS, and ASA out of the box. Add more platforms to the
    $platformCommands table as needed.

.PARAMETER DeviceListPath
    Path to a CSV with columns: Hostname, Platform, [Port]. Platform must be one of the
    keys in $platformCommands (IOS-XE, NX-OS, ASA).

.PARAMETER Credential
    Credential used to authenticate to every device in the list. Prompted if not supplied.

.PARAMETER OutputPath
    Root folder to write backups to. A subfolder is created per device.

.EXAMPLE
    .\Backup-NetworkDeviceConfig.ps1 -DeviceListPath .\devices.csv -OutputPath C:\NetworkBackups

.NOTES
    devices.csv example:
        Hostname,Platform,Port
        core-sw01.corp.local,NX-OS,22
        isr-rtr01.corp.local,IOS-XE,22
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$DeviceListPath,

    [System.Management.Automation.PSCredential]$Credential,

    [string]$OutputPath = ".\NetworkBackups"
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable -Name Posh-SSH)) {
    throw "The Posh-SSH module is required. Install it with: Install-Module Posh-SSH -Scope CurrentUser"
}
Import-Module Posh-SSH

if (-not $Credential) {
    $Credential = Get-Credential -Message "Credentials for network device SSH access"
}

if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory | Out-Null
}

# Map platform -> command used to display the running config
$platformCommands = @{
    'IOS-XE' = 'show running-config'
    'NX-OS'  = 'show running-config'
    'ASA'    = 'show running-config'
}

$devices = Import-Csv -Path $DeviceListPath
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$results = @()

foreach ($device in $devices) {
    $hostname = $device.Hostname
    $platform = $device.Platform
    $port     = if ($device.Port) { [int]$device.Port } else { 22 }
    $session  = $null

    if (-not $platformCommands.ContainsKey($platform)) {
        Write-Warning "Skipping '$hostname' - unknown platform '$platform'."
        continue
    }

    Write-Host "Connecting to $hostname ($platform)..." -ForegroundColor Cyan

    try {
        $session = New-SSHSession -ComputerName $hostname -Port $port -Credential $Credential -AcceptKey -ErrorAction Stop
        $command = $platformCommands[$platform]
        $stream  = New-SSHShellStream -SSHSession $session

        $stream.WriteLine('terminal length 0')
        Start-Sleep -Milliseconds 500
        $stream.WriteLine($command)
        Start-Sleep -Seconds 2
        $output = $stream.Read()

        $deviceFolder = Join-Path $OutputPath $hostname
        if (-not (Test-Path $deviceFolder)) {
            New-Item -Path $deviceFolder -ItemType Directory | Out-Null
        }

        $backupFile = Join-Path $deviceFolder "$hostname-$timestamp.cfg"
        $output | Out-File -FilePath $backupFile -Encoding utf8

        Write-Host "  Saved backup to $backupFile" -ForegroundColor Green
        $results += [PSCustomObject]@{ Hostname = $hostname; Platform = $platform; Status = 'Success'; File = $backupFile }
    }
    catch {
        Write-Warning "  Failed to back up $hostname : $($_.Exception.Message)"
        $results += [PSCustomObject]@{ Hostname = $hostname; Platform = $platform; Status = 'Failed'; File = $null }
    }
    finally {
        if ($session) {
            Remove-SSHSession -SSHSession $session | Out-Null
        }
    }
}

$results | Format-Table -AutoSize
