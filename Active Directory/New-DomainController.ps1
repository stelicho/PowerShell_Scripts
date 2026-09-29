<#
.SYNOPSIS
    Installs AD DS and promotes this server to the first Domain Controller
    of a brand-new Active Directory forest.

.DESCRIPTION
    Run this on a clean Windows Server that will become your first DC.
    The server will reboot automatically at the end of promotion unless
    -NoReboot is specified.

.PARAMETER DomainName
    Fully qualified domain name for the new forest, e.g. "corp.contoso.com".

.PARAMETER NetBiosName
    NetBIOS name for the domain, e.g. "CORP". Defaults to the first label
    of DomainName if not supplied.

.PARAMETER SafeModeAdminPassword
    SecureString password for Directory Services Restore Mode (DSRM).
    If not supplied, you will be prompted securely.

.PARAMETER DomainMode / ForestMode
    Functional level for the new domain/forest. Defaults to WinThreshold
    (Server 2016+ functional level).

.PARAMETER DatabasePath / LogPath / SysvolPath
    Optional custom paths for the NTDS database, logs, and SYSVOL.

.PARAMETER NoReboot
    Skip the automatic reboot after promotion completes.

.EXAMPLE
    .\New-DomainController.ps1 -DomainName "corp.contoso.com"

.EXAMPLE
    $pw = Read-Host "DSRM password" -AsSecureString
    .\New-DomainController.ps1 -DomainName "corp.contoso.com" -NetBiosName "CORP" -SafeModeAdminPassword $pw
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$')]
    [string]$DomainName,

    [ValidateLength(1, 15)]
    [string]$NetBiosName,

    [System.Security.SecureString]$SafeModeAdminPassword,

    [ValidateSet('Win2012R2', 'Win2016', 'WinThreshold')]
    [string]$DomainMode = 'WinThreshold',

    [ValidateSet('Win2012R2', 'Win2016', 'WinThreshold')]
    [string]$ForestMode = 'WinThreshold',

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

function Assert-NotAlreadyDomainController {
    $cs = Get-CimInstance -ClassName Win32_ComputerSystem
    if ($cs.DomainRole -in 2, 4, 5) {
        throw "This server already appears to be a Domain Controller (DomainRole=$($cs.DomainRole))."
    }
}

Assert-Administrator
Assert-NotAlreadyDomainController

if (-not $NetBiosName) {
    $NetBiosName = ($DomainName.Split('.')[0]).ToUpper()
    Write-Verbose "NetBiosName not supplied; derived '$NetBiosName' from DomainName."
}

if (-not $SafeModeAdminPassword) {
    $SafeModeAdminPassword = Read-Host -Prompt 'Enter the Directory Services Restore Mode (DSRM) password' -AsSecureString
}

Write-Host "Installing AD DS role and management tools..." -ForegroundColor Cyan
Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools | Out-Null

Import-Module ADDSDeployment

$installParams = @{
    DomainName                    = $DomainName
    DomainNetbiosName             = $NetBiosName
    SafeModeAdministratorPassword = $SafeModeAdminPassword
    DomainMode                    = $DomainMode
    ForestMode                    = $ForestMode
    DatabasePath                  = $DatabasePath
    LogPath                       = $LogPath
    SysvolPath                    = $SysvolPath
    InstallDns                    = $true
    CreateDnsDelegation           = $false
    NoRebootOnCompletion          = $NoReboot.IsPresent
    Force                        = $true
    Confirm                       = $false
}

if ($PSCmdlet.ShouldProcess($DomainName, "Install new AD forest and promote this server to Domain Controller")) {
    Write-Host "Promoting server to Domain Controller for new forest '$DomainName'..." -ForegroundColor Cyan
    Install-ADDSForest @installParams

    if ($NoReboot) {
        Write-Host "Promotion complete. A reboot is required before AD DS is fully operational." -ForegroundColor Yellow
    }
    else {
        Write-Host "Promotion complete. The server is rebooting to finish setup." -ForegroundColor Green
    }
}
