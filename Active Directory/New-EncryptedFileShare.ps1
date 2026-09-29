<#
.SYNOPSIS
    Creates a new SMB file share with encryption-in-transit enabled and
    access locked down to a dedicated AD security group.

.DESCRIPTION
    Rough-draft compliance-oriented file share provisioning script (the kind
    of PCI DSS/HIPAA-style control requiring encrypted data in transit and
    access restricted to a defined group). Creates the folder, creates a
    matching AD security group if it doesn't already exist, sets NTFS
    permissions to that group only (plus SYSTEM/Administrators), and
    publishes the share with SMB 3.0 "Encrypt Data Access" turned on.

.PARAMETER ShareName
    Name the share will be published as.

.PARAMETER SharePath
    Local path on the file server to share, e.g. "D:\Shares\Finance".

.PARAMETER AccessGroupName
    Name of the AD security group that will be granted access. Created if it doesn't already exist.

.PARAMETER AccessGroupOuPath
    OU distinguished name to create the new access group in, if it needs to be created.

.PARAMETER NtfsPermission
    NTFS permission level to grant the access group. Default: Modify.

.PARAMETER RequireEncryption
    Enforces SMB encryption for all clients connecting to the share when
    true (default); clients that don't support SMB 3.0 encryption are denied
    access rather than falling back to an unencrypted connection.

.EXAMPLE
    .\New-EncryptedFileShare.ps1 -ShareName "Finance" -SharePath "D:\Shares\Finance" `
        -AccessGroupName "SG-Finance-Share" -AccessGroupOuPath "OU=Groups,DC=corp,DC=contoso,DC=com"
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$ShareName,

    [Parameter(Mandatory)]
    [string]$SharePath,

    [Parameter(Mandatory)]
    [string]$AccessGroupName,

    [string]$AccessGroupOuPath,

    [ValidateSet('Read', 'Change', 'Modify', 'FullControl')]
    [string]$NtfsPermission = 'Modify',

    [bool]$RequireEncryption = $true
)

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory
Import-Module SmbShare

# --- Ensure the AD access group exists ---
$group = Get-ADGroup -Filter "Name -eq '$AccessGroupName'" -ErrorAction SilentlyContinue
if (-not $group) {
    if (-not $AccessGroupOuPath) {
        throw "Access group '$AccessGroupName' does not exist and -AccessGroupOuPath was not supplied to create it."
    }
    if ($PSCmdlet.ShouldProcess($AccessGroupName, "Create AD security group")) {
        $group = New-ADGroup -Name $AccessGroupName -GroupScope DomainLocal -GroupCategory Security -Path $AccessGroupOuPath -PassThru
        Write-Host "Created AD security group '$AccessGroupName'." -ForegroundColor Green
    }
}
else {
    Write-Host "Using existing AD security group '$AccessGroupName'." -ForegroundColor Cyan
}

# --- Create the folder and lock down NTFS permissions ---
if (-not (Test-Path $SharePath)) {
    if ($PSCmdlet.ShouldProcess($SharePath, "Create folder")) {
        New-Item -Path $SharePath -ItemType Directory -Force | Out-Null
    }
}

if ($PSCmdlet.ShouldProcess($SharePath, "Set NTFS permissions for '$AccessGroupName'")) {
    $acl = Get-Acl -Path $SharePath
    $acl.SetAccessRuleProtection($true, $false)  # disable inheritance, drop inherited rules

    foreach ($principal in 'NT AUTHORITY\SYSTEM', 'BUILTIN\Administrators') {
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($principal, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
        $acl.AddAccessRule($rule)
    }

    $groupRule = New-Object System.Security.AccessControl.FileSystemAccessRule($AccessGroupName, $NtfsPermission, 'ContainerInherit,ObjectInherit', 'None', 'Allow')
    $acl.AddAccessRule($groupRule)

    Set-Acl -Path $SharePath -AclObject $acl
    Write-Host "NTFS permissions locked to SYSTEM, Administrators, and '$AccessGroupName' ($NtfsPermission)." -ForegroundColor Green
}

# --- Publish the SMB share with encryption enabled ---
if ($PSCmdlet.ShouldProcess($ShareName, "Create SMB share with encryption")) {
    if (Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue) {
        throw "A share named '$ShareName' already exists on this server."
    }

    New-SmbShare -Name $ShareName -Path $SharePath -FullAccess "$env:USERDOMAIN\$AccessGroupName" -EncryptData $RequireEncryption | Out-Null

    Write-Host "Published share '\\$env:COMPUTERNAME\$ShareName' with SMB encryption $(if ($RequireEncryption) { 'REQUIRED' } else { 'disabled' })." -ForegroundColor Green
    Write-Host "Grant additional users access to this data by adding them to the '$AccessGroupName' AD group." -ForegroundColor Cyan
}
