function Get-NinjaDiskHealth {
    <#
    .SYNOPSIS
        Reports free space and physical disk health (SMART/reliability status) for local fixed disks.

    .PARAMETER FreeSpaceWarningPct
        Flag volumes with free space at or below this percentage. Default: 10.

    .EXAMPLE
        Get-NinjaDiskHealth

    .EXAMPLE
        Get-NinjaDiskHealth -FreeSpaceWarningPct 15
    #>
    [CmdletBinding()]
    param(
        [int]$FreeSpaceWarningPct = 10
    )

    $volumes = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
        $freePct = [math]::Round(($_.FreeSpace / $_.Size) * 100, 1)
        [PSCustomObject]@{
            Drive    = $_.DeviceID
            SizeGB   = [math]::Round($_.Size / 1GB, 1)
            FreeGB   = [math]::Round($_.FreeSpace / 1GB, 1)
            FreePct  = $freePct
            LowSpace = $freePct -le $FreeSpaceWarningPct
        }
    }

    $physicalDisks = Get-PhysicalDisk -ErrorAction SilentlyContinue |
        Select-Object DeviceId, FriendlyName, MediaType, HealthStatus, OperationalStatus

    [PSCustomObject]@{
        Volumes       = $volumes
        PhysicalDisks = $physicalDisks
        AnyLowSpace   = [bool]($volumes | Where-Object LowSpace)
        AnyUnhealthy  = [bool]($physicalDisks | Where-Object { $_.HealthStatus -ne 'Healthy' })
    }
}
