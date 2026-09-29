function Get-NinjaPendingRebootStatus {
    <#
    .SYNOPSIS
        Checks the common indicators that a Windows host has a pending reboot.

    .DESCRIPTION
        Checks Component Based Servicing, Windows Update, and pending file
        rename operations - the three most common reasons endpoints silently
        need a reboot to finish applying updates.

    .EXAMPLE
        Get-NinjaPendingRebootStatus
    #>
    [CmdletBinding()]
    param()

    $cbsPending = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
    $wuPending  = Test-Path 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\Auto Update\RebootRequired'
    $fileRenamePending = [bool](Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue)

    [PSCustomObject]@{
        ComponentBasedServicing = $cbsPending
        WindowsUpdate           = $wuPending
        PendingFileRename       = $fileRenamePending
        RebootPending           = $cbsPending -or $wuPending -or $fileRenamePending
    }
}
