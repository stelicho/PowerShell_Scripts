<#
.SYNOPSIS
    Collects a quick health snapshot of a Windows workstation for helpdesk/desktop
    support triage: disk space, pending reboot, uptime, AV status, and Windows Update backlog.

.DESCRIPTION
    Rough-draft health check intended to be run locally or remotely (via Invoke-Command
    or RMM script deployment) against end-user workstations. Designed to surface the
    handful of things that most commonly cause helpdesk tickets before the user even calls in.

.PARAMETER ComputerName
    One or more remote computers to check. Defaults to the local machine.

.PARAMETER Credential
    Credential to use for remote checks.

.EXAMPLE
    .\Get-WorkstationHealthReport.ps1

.EXAMPLE
    .\Get-WorkstationHealthReport.ps1 -ComputerName PC-JDOE, PC-ASMITH
#>

[CmdletBinding()]
param(
    [string[]]$ComputerName = $env:COMPUTERNAME,
    [System.Management.Automation.PSCredential]$Credential
)

$scriptBlock = {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $uptime = (Get-Date) - $os.LastBootUpTime

    $disks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
        [PSCustomObject]@{
            Drive   = $_.DeviceID
            FreeGB  = [math]::Round($_.FreeSpace / 1GB, 1)
            TotalGB = [math]::Round($_.Size / 1GB, 1)
            FreePct = [math]::Round(($_.FreeSpace / $_.Size) * 100, 1)
        }
    }

    $pendingReboot = $false
    $rebootKeys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\Auto Update\RebootRequired'
    )
    foreach ($key in $rebootKeys) {
        if (Test-Path $key) { $pendingReboot = $true }
    }

    $av = Get-CimInstance -Namespace 'root\SecurityCenter2' -ClassName AntiVirusProduct -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty displayName

    try {
        $updateSession  = New-Object -ComObject Microsoft.Update.Session
        $updateSearcher = $updateSession.CreateUpdateSearcher()
        $pendingUpdates = ($updateSearcher.Search("IsInstalled=0").Updates).Count
    }
    catch {
        $pendingUpdates = 'Unavailable'
    }

    [PSCustomObject]@{
        ComputerName     = $env:COMPUTERNAME
        OSVersion        = $os.Caption
        LastBootUpTime   = $os.LastBootUpTime
        UptimeDays       = [math]::Round($uptime.TotalDays, 1)
        PendingReboot    = $pendingReboot
        AntivirusProduct = $av
        PendingUpdates   = $pendingUpdates
        Disks            = $disks
    }
}

$results = foreach ($computer in $ComputerName) {
    if ($computer -eq $env:COMPUTERNAME) {
        & $scriptBlock
    }
    else {
        $params = @{ ComputerName = $computer; ScriptBlock = $scriptBlock }
        if ($Credential) { $params.Credential = $Credential }
        Invoke-Command @params
    }
}

foreach ($r in $results) {
    Write-Host "`n== $($r.ComputerName) ==" -ForegroundColor Cyan
    Write-Host "OS: $($r.OSVersion)  |  Uptime: $($r.UptimeDays) days  |  Pending Reboot: $($r.PendingReboot)"
    Write-Host "Antivirus: $($r.AntivirusProduct)  |  Pending Updates: $($r.PendingUpdates)"
    $r.Disks | Format-Table -AutoSize
}
