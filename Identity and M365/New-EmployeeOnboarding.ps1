<#
.SYNOPSIS
    Onboards a new employee: creates the on-prem AD account and group memberships,
    then (once Entra Connect has synced) assigns an M365 license via Microsoft Graph.

.DESCRIPTION
    Rough-draft onboarding script for hybrid AD environments (on-prem AD + Entra
    Connect + Microsoft 365). Two-phase by design:
      1. Create the on-prem AD user and group memberships.
      2. After the next Entra Connect sync cycle, run again with -AssignLicense to
         assign an M365 license via Microsoft Graph.

.PARAMETER FirstName / LastName
    Employee's name, used to build the SamAccountName and UPN.

.PARAMETER Department
    Department name; used to place the user in a matching security group.

.PARAMETER Manager
    SamAccountName of the employee's manager, set as the AD "Manager" attribute.

.PARAMETER OuPath
    Distinguished name of the OU to create the account in.

.PARAMETER Groups
    Additional AD security groups to add the new user to.

.PARAMETER AssignLicense
    Switch. When specified, skips AD account creation and instead assigns an
    M365 license to an already-synced user via Microsoft Graph.

.PARAMETER UserPrincipalName
    Required with -AssignLicense. UPN of the already-synced user.

.PARAMETER LicenseSkuId
    Required with -AssignLicense. SKU ID of the M365 license to assign
    (see Get-MgSubscribedSku).

.EXAMPLE
    .\New-EmployeeOnboarding.ps1 -FirstName Jane -LastName Doe -Department Sales `
        -Manager jsmith -OuPath "OU=Sales,OU=Employees,DC=corp,DC=contoso,DC=com"

.EXAMPLE
    .\New-EmployeeOnboarding.ps1 -AssignLicense -UserPrincipalName jane.doe@contoso.com -LicenseSkuId <guid>
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$FirstName,
    [string]$LastName,
    [string]$Department,
    [string]$Manager,
    [string]$OuPath,
    [string[]]$Groups,

    [switch]$AssignLicense,
    [string]$UserPrincipalName,
    [string]$LicenseSkuId
)

$ErrorActionPreference = 'Stop'

if ($AssignLicense) {
    if (-not $UserPrincipalName -or -not $LicenseSkuId) {
        throw "UserPrincipalName and LicenseSkuId are required with -AssignLicense."
    }

    Import-Module Microsoft.Graph.Users
    Connect-MgGraph -Scopes "User.ReadWrite.All", "Organization.Read.All"

    $mgUser = Get-MgUser -UserId $UserPrincipalName
    if ($PSCmdlet.ShouldProcess($UserPrincipalName, "Assign M365 license $LicenseSkuId")) {
        Set-MgUserLicense -UserId $mgUser.Id -AddLicenses @{ SkuId = $LicenseSkuId } -RemoveLicenses @()
        Write-Host "License assigned to $UserPrincipalName." -ForegroundColor Green
    }
    return
}

foreach ($required in 'FirstName', 'LastName', 'Department', 'OuPath') {
    if (-not (Get-Variable -Name $required -ValueOnly)) {
        throw "-$required is required when creating a new AD account."
    }
}

Import-Module ActiveDirectory
Add-Type -AssemblyName System.Web

$samAccountName = ("{0}.{1}" -f $FirstName, $LastName).ToLower()
$upnDomain      = (Get-ADDomain).DNSRoot
$userPrincipal  = "$samAccountName@$upnDomain"
$displayName    = "$FirstName $LastName"
$tempPassword   = ConvertTo-SecureString ([System.Web.Security.Membership]::GeneratePassword(16, 4)) -AsPlainText -Force

if ($PSCmdlet.ShouldProcess($displayName, "Create AD user in $OuPath")) {
    New-ADUser `
        -Name $displayName `
        -GivenName $FirstName `
        -Surname $LastName `
        -SamAccountName $samAccountName `
        -UserPrincipalName $userPrincipal `
        -Path $OuPath `
        -Department $Department `
        -Manager $Manager `
        -AccountPassword $tempPassword `
        -ChangePasswordAtLogon $true `
        -Enabled $true

    Write-Host "Created AD user '$samAccountName' in $OuPath." -ForegroundColor Green

    $defaultGroup = "SG-$Department"
    $allGroups = @($defaultGroup) + $Groups
    foreach ($group in $allGroups | Select-Object -Unique) {
        try {
            Add-ADGroupMember -Identity $group -Members $samAccountName
            Write-Host "  Added to group '$group'." -ForegroundColor Green
        }
        catch {
            Write-Warning "  Could not add to group '$group': $($_.Exception.Message)"
        }
    }

    Write-Host "Temporary password has been set; user must change it at next logon." -ForegroundColor Yellow
    Write-Host "Once Entra Connect has synced this account, run with -AssignLicense to grant an M365 license." -ForegroundColor Cyan
}
