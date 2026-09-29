<#
.SYNOPSIS
    Installs AD DS and promotes this server to an additional Domain Controller
    in an existing Active Directory domain.

.DESCRIPTION
    Complement to New-DomainController.ps1 (which stands up the first DC of a
    brand-new forest). Use this script to add a second/replica DC to a domain
    that already exists, for redundancy or site-local authentication.

.PARAMETER DomainName
    Fully qualified domain name of the existing domain to join as a DC, e.g. "corp.contoso.com".

.PARAMETER SiteName
    AD site to associate this DC with. Defaults to the site the server's IP maps to if omitted.

.PARAMETER SafeModeAdminPassword
    SecureString password for Directory Services Restore Mode (DSRM). Prompted if not supplied.

.PARAMETER Credential
    Domain credential with rights to add a DC (typically Domain/Enterprise Admin). Prompted if not supplied.

.PARAMETER DatabasePath / LogPath / SysvolPath
    Optional custom paths for the NTDS database, logs, and SYSVOL.

.PARAMETER NoReboot
    Skip the automatic reboot after promotion completes.

.EXAMPLE
    .\Install-ADDSDomainController.ps1 -DomainName "corp.contoso.com" -SiteName "Portland"
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$DomainName,

    [string]$SiteName,

    [System.Security.SecureString]$SafeModeAdminPassword,

    [System.Management.Automation.PSCredential]$Credential,

    [string]$DatabasePath = 'C:\Windows\NTDS',
    [string]$LogPath      = 'C:\Windows\NTDS',
    [string]$SysvolPath   = 'C:\Windows\SYSVOL',

    [switch]$NoReboot
)

$ErrorActionPreference = 'Stop'

function Assert-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal   = New-Object Security.Principal.WindowsPrincipal($currentUser)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "This script must be run from an elevated (Administrator) PowerShell session."
    }
}

Assert-Administrator

if (-not $Credential) {
    $Credential = Get-Credential -Message "Domain credential with rights to add a Domain Controller to $DomainName"
}

if (-not $SafeModeAdminPassword) {
    $SafeModeAdminPassword = Read-Host -Prompt 'Enter the Directory Services Restore Mode (DSRM) password' -AsSecureString
}

Write-Host "Installing AD DS role and management tools..." -ForegroundColor Cyan
Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools | Out-Null

Import-Module ADDSDeployment

$installParams = @{
    DomainName                    = $DomainName
    Credential                    = $Credential
    SafeModeAdministratorPassword = $SafeModeAdminPassword
    DatabasePath                  = $DatabasePath
    LogPath                       = $LogPath
    SysvolPath                    = $SysvolPath
    InstallDns                    = $true
    NoRebootOnCompletion          = $NoReboot.IsPresent
    Force                         = $true
    Confirm                       = $false
}
if ($SiteName) {
    $installParams.SiteName = $SiteName
}

if ($PSCmdlet.ShouldProcess($DomainName, "Promote this server to an additional Domain Controller")) {
    Write-Host "Promoting server to an additional Domain Controller for '$DomainName'..." -ForegroundColor Cyan
    Install-ADDSDomainController @installParams

    if ($NoReboot) {
        Write-Host "Promotion complete. A reboot is required before AD DS is fully operational." -ForegroundColor Yellow
    }
    else {
        Write-Host "Promotion complete. The server is rebooting to finish setup." -ForegroundColor Green
    }
}
