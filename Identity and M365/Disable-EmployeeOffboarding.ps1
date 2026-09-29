<#
.SYNOPSIS
    Offboards a departing employee: disables the AD account, strips group
    memberships, moves them to a "Disabled Users" OU, and optionally revokes
    M365 sessions/licenses.

.DESCRIPTION
    Rough-draft offboarding script for hybrid AD + Microsoft 365 environments.
    Handles the on-prem AD side immediately and, if -RevokeM365 is specified,
    also revokes the user's Entra ID sign-in sessions and removes all assigned
    M365 licenses via Microsoft Graph.

.PARAMETER SamAccountName
    The AD account to disable.

.PARAMETER DisabledOuPath
    Distinguished name of the OU to move disabled accounts into.

.PARAMETER RevokeM365
    If specified, also revokes the user's Entra ID sign-in sessions and removes
    all assigned M365 licenses via Microsoft Graph.

.EXAMPLE
    .\Disable-EmployeeOffboarding.ps1 -SamAccountName jane.doe -DisabledOuPath "OU=Disabled Users,DC=corp,DC=contoso,DC=com" -RevokeM365
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$SamAccountName,

    [Parameter(Mandatory)]
    [string]$DisabledOuPath,

    [switch]$RevokeM365
)

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

$user = Get-ADUser -Identity $SamAccountName -Properties MemberOf, DistinguishedName

if ($PSCmdlet.ShouldProcess($SamAccountName, "Disable AD account and move to $DisabledOuPath")) {
    Disable-ADAccount -Identity $SamAccountName
    Write-Host "Disabled AD account '$SamAccountName'." -ForegroundColor Green

    foreach ($group in $user.MemberOf) {
        try {
            Remove-ADGroupMember -Identity $group -Members $SamAccountName -Confirm:$false
        }
        catch {
            Write-Warning "Could not remove from group '$group': $($_.Exception.Message)"
        }
    }
    Write-Host "Removed all group memberships." -ForegroundColor Green

    Move-ADObject -Identity $user.DistinguishedName -TargetPath $DisabledOuPath
    Write-Host "Moved account to $DisabledOuPath." -ForegroundColor Green

    $randomPassword = ConvertTo-SecureString ((New-Guid).Guid) -AsPlainText -Force
    Set-ADAccountPassword -Identity $SamAccountName -NewPassword $randomPassword -Reset
    Write-Host "Reset password to a random value." -ForegroundColor Green
}

if ($RevokeM365) {
    Import-Module Microsoft.Graph.Users
    Import-Module Microsoft.Graph.Identity.SignIns
    Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All"

    $upn = "$SamAccountName@$((Get-ADDomain).DNSRoot)"
    $mgUser = Get-MgUser -UserId $upn -Property Id, AssignedLicenses

    if ($PSCmdlet.ShouldProcess($upn, "Revoke sign-in sessions and remove M365 licenses")) {
        Revoke-MgUserSignInSession -UserId $mgUser.Id
        Write-Host "Revoked active sign-in sessions for $upn." -ForegroundColor Green

        $skuIds = @($mgUser.AssignedLicenses | Select-Object -ExpandProperty SkuId)
        if ($skuIds.Count -gt 0) {
            Set-MgUserLicense -UserId $mgUser.Id -AddLicenses @() -RemoveLicenses $skuIds
            Write-Host "Removed $($skuIds.Count) license(s) from $upn." -ForegroundColor Green
        }
    }
}
