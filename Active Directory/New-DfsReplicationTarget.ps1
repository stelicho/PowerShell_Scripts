<#
.SYNOPSIS
    Creates a new DFS Replication group (or adds a replication target/member
    to an existing group) to replicate a folder between two servers.

.DESCRIPTION
    Rough-draft DFSR provisioning script. Two modes:
      - New group (-NewGroup): creates the replication group and replicated
        folder, adds both members, connects them, and sets membership
        (content path, primary member, read-only option).
      - Existing group (default): adds a new member/target server to an
        already existing replication group and folder.

.PARAMETER ReplicationGroupName
    Name of the DFS Replication group to create or add a target to.

.PARAMETER ReplicatedFolderName
    Name of the replicated folder within the group.

.PARAMETER SourceComputerName / SourceContentPath
    The existing/primary server and local path being replicated FROM.
    Required with -NewGroup.

.PARAMETER TargetComputerName / TargetContentPath
    The new server and local path being replicated TO.

.PARAMETER DomainName
    AD domain the replication group lives in. Defaults to the current domain.

.PARAMETER ReadOnlyTarget
    If specified, the target member is configured as a read-only replica.

.PARAMETER NewGroup
    If specified, creates a brand-new replication group. Omit this switch to
    instead add TargetComputerName as a new member/target to an existing group.

.EXAMPLE
    .\New-DfsReplicationTarget.ps1 -NewGroup -ReplicationGroupName "Branch-FileSync" `
        -ReplicatedFolderName "Shared" -SourceComputerName FS01 -SourceContentPath "D:\Shares\Shared" `
        -TargetComputerName FS02 -TargetContentPath "D:\Shares\Shared"

.EXAMPLE
    .\New-DfsReplicationTarget.ps1 -ReplicationGroupName "Branch-FileSync" -ReplicatedFolderName "Shared" `
        -TargetComputerName FS03 -TargetContentPath "D:\Shares\Shared" -ReadOnlyTarget
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$ReplicationGroupName,

    [Parameter(Mandatory)]
    [string]$ReplicatedFolderName,

    [string]$SourceComputerName,
    [string]$SourceContentPath,

    [Parameter(Mandatory)]
    [string]$TargetComputerName,

    [Parameter(Mandatory)]
    [string]$TargetContentPath,

    [string]$DomainName = (Get-ADDomain).DNSRoot,

    [switch]$ReadOnlyTarget,
    [switch]$NewGroup
)

$ErrorActionPreference = 'Stop'
Import-Module DFSR
Import-Module ActiveDirectory

if ($NewGroup) {
    if (-not $SourceComputerName -or -not $SourceContentPath) {
        throw "-SourceComputerName and -SourceContentPath are required when creating a new replication group with -NewGroup."
    }

    if ($PSCmdlet.ShouldProcess($ReplicationGroupName, "Create new DFS Replication group")) {
        New-DfsReplicationGroup -GroupName $ReplicationGroupName -DomainName $DomainName | Out-Null
        New-DfsReplicatedFolder -GroupName $ReplicationGroupName -FolderName $ReplicatedFolderName -DomainName $DomainName | Out-Null

        Add-DfsrMember -GroupName $ReplicationGroupName -ComputerName $SourceComputerName, $TargetComputerName -DomainName $DomainName

        Set-DfsrMembership -GroupName $ReplicationGroupName -FolderName $ReplicatedFolderName `
            -ComputerName $SourceComputerName -ContentPath $SourceContentPath -PrimaryMember $true -DomainName $DomainName -Force

        Set-DfsrMembership -GroupName $ReplicationGroupName -FolderName $ReplicatedFolderName `
            -ComputerName $TargetComputerName -ContentPath $TargetContentPath -ReadOnly $ReadOnlyTarget.IsPresent -DomainName $DomainName -Force

        Add-DfsrConnection -GroupName $ReplicationGroupName -SourceComputerName $SourceComputerName -DestinationComputerName $TargetComputerName -DomainName $DomainName

        Write-Host "Created replication group '$ReplicationGroupName' replicating '$ReplicatedFolderName' from $SourceComputerName to $TargetComputerName." -ForegroundColor Green
    }
}
else {
    if ($PSCmdlet.ShouldProcess($TargetComputerName, "Add as a new DFSR target to group '$ReplicationGroupName'")) {
        Add-DfsrMember -GroupName $ReplicationGroupName -ComputerName $TargetComputerName -DomainName $DomainName

        Set-DfsrMembership -GroupName $ReplicationGroupName -FolderName $ReplicatedFolderName `
            -ComputerName $TargetComputerName -ContentPath $TargetContentPath -ReadOnly $ReadOnlyTarget.IsPresent -DomainName $DomainName -Force

        if ($SourceComputerName) {
            Add-DfsrConnection -GroupName $ReplicationGroupName -SourceComputerName $SourceComputerName -DestinationComputerName $TargetComputerName -DomainName $DomainName
        }
        else {
            Write-Warning "No -SourceComputerName supplied - remember to add a DFSR connection from an existing member to $TargetComputerName manually."
        }

        Write-Host "Added $TargetComputerName as a new DFSR target for '$ReplicatedFolderName' in group '$ReplicationGroupName'." -ForegroundColor Green
    }
}
