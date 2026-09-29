<#
.SYNOPSIS
    Bulk-creates Active Directory user accounts from a CSV file.

.DESCRIPTION
    Rough-draft bulk provisioning script. Reads a CSV of new hires and creates
    an AD account for each, setting a temporary password that must be changed
    at next logon and adding the user to any groups listed in the CSV.

.PARAMETER CsvPath
    Path to a CSV with columns: FirstName, LastName, Department, OuPath, Manager, Groups
    (Groups is a semicolon-separated list, e.g. "SG-Sales;VPN-Users").

.EXAMPLE
    .\New-ADBulkUser.ps1 -CsvPath .\new-hires.csv

.NOTES
    new-hires.csv example:
        FirstName,LastName,Department,OuPath,Manager,Groups
        Jane,Doe,Sales,"OU=Sales,OU=Employees,DC=corp,DC=contoso,DC=com",jsmith,"SG-Sales;VPN-Users"
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$CsvPath
)

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory
Add-Type -AssemblyName System.Web

$upnDomain = (Get-ADDomain).DNSRoot
$newHires  = Import-Csv -Path $CsvPath
$results   = @()

foreach ($hire in $newHires) {
    $samAccountName = ("{0}.{1}" -f $hire.FirstName, $hire.LastName).ToLower()
    $displayName    = "$($hire.FirstName) $($hire.LastName)"
    $userPrincipal  = "$samAccountName@$upnDomain"
    $tempPassword   = ConvertTo-SecureString ([System.Web.Security.Membership]::GeneratePassword(16, 4)) -AsPlainText -Force

    if (Get-ADUser -Filter "SamAccountName -eq '$samAccountName'" -ErrorAction SilentlyContinue) {
        Write-Warning "Skipping $displayName - account '$samAccountName' already exists."
        $results += [PSCustomObject]@{ Name = $displayName; SamAccountName = $samAccountName; Status = 'Skipped (exists)' }
        continue
    }

    if ($PSCmdlet.ShouldProcess($displayName, "Create AD user in $($hire.OuPath)")) {
        try {
            New-ADUser `
                -Name $displayName `
                -GivenName $hire.FirstName `
                -Surname $hire.LastName `
                -SamAccountName $samAccountName `
                -UserPrincipalName $userPrincipal `
                -Path $hire.OuPath `
                -Department $hire.Department `
                -Manager $hire.Manager `
                -AccountPassword $tempPassword `
                -ChangePasswordAtLogon $true `
                -Enabled $true

            if ($hire.Groups) {
                foreach ($group in ($hire.Groups -split ';')) {
                    Add-ADGroupMember -Identity $group.Trim() -Members $samAccountName
                }
            }

            Write-Host "Created $displayName ($samAccountName)." -ForegroundColor Green
            $results += [PSCustomObject]@{ Name = $displayName; SamAccountName = $samAccountName; Status = 'Created' }
        }
        catch {
            Write-Warning "Failed to create $displayName : $($_.Exception.Message)"
            $results += [PSCustomObject]@{ Name = $displayName; SamAccountName = $samAccountName; Status = "Failed: $($_.Exception.Message)" }
        }
    }
}

$results | Format-Table -AutoSize
