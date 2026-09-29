<#
.SYNOPSIS
    Collects this device's hardware hash and registers it with Windows
    Autopilot via Microsoft Graph for zero-touch deployment.

.DESCRIPTION
    Rough-draft version of the community "Get-WindowsAutopilotInfo" pattern,
    built directly on the Microsoft.Graph.DeviceManagement.Enrollment module
    so collect-hash -> upload -> assign group tag lives in one script.

.PARAMETER GroupTag
    Optional Autopilot group tag to assign, used to drive dynamic Autopilot
    deployment profile assignment.

.PARAMETER AssignedUser
    Optional UPN to pre-assign the device to a specific user.

.EXAMPLE
    .\Register-AutopilotDevice.ps1 -GroupTag "Sales-Laptops"
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$GroupTag,
    [string]$AssignedUser
)

$ErrorActionPreference = 'Stop'

Import-Module Microsoft.Graph.DeviceManagement.Enrollment
Connect-MgGraph -Scopes "DeviceManagementServiceConfig.ReadWrite.All"

Write-Host "Collecting hardware hash from this device..." -ForegroundColor Cyan
$serial = (Get-CimInstance -ClassName Win32_BIOS).SerialNumber
$hash   = (Get-CimInstance -Namespace root/cimv2/mdm/dmmap -ClassName MDM_DevDetail_Ext01 -Filter "InstanceID='Ext' AND ParentID='./DevDetail'").DeviceHardwareData

if (-not $hash) {
    throw "Could not read the device hardware hash (MDM_DevDetail_Ext01). Run this from an elevated session on the physical device being enrolled."
}

$body = @{
    serialNumber              = $serial
    hardwareIdentifier        = $hash
    groupTag                  = $GroupTag
    assignedUserPrincipalName = $AssignedUser
}

if ($PSCmdlet.ShouldProcess($serial, "Register device with Windows Autopilot")) {
    New-MgDeviceManagementImportedWindowsAutopilotDeviceIdentity -BodyParameter $body
    Write-Host "Submitted device (serial $serial) for Autopilot registration. Sync can take several minutes to appear in Intune." -ForegroundColor Green
}
