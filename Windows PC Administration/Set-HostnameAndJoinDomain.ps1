<#
.SYNOPSIS
    Renames this computer and joins it to an Active Directory domain in one step.

.DESCRIPTION
    Common new-PC deployment/imaging task. Renames the local computer (if a
    new name is supplied and differs from the current one) and joins it to
    the target domain, optionally placing the computer object in a specific
    OU, then reboots to finish.

.PARAMETER NewName
    New computer name. If omitted, the current name is kept and only a domain join is performed.

.PARAMETER DomainName
    FQDN of the domain to join, e.g. "corp.contoso.com".

.PARAMETER OuPath
    Optional distinguished name of the OU to place the computer object in.

.PARAMETER Credential
    Domain credential with rights to join computers to the domain. Prompted if not supplied.

.PARAMETER NoRestart
    Skip the automatic reboot after the rename/join completes.

.EXAMPLE
    .\Set-HostnameAndJoinDomain.ps1 -NewName "PDX-LT-0231" -DomainName "corp.contoso.com" `
        -OuPath "OU=Laptops,OU=Workstations,DC=corp,DC=contoso,DC=com"
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$NewName,

    [Parameter(Mandatory)]
    [string]$DomainName,

    [string]$OuPath,

    [System.Management.Automation.PSCredential]$Credential,

    [switch]$NoRestart
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

$cs = Get-CimInstance -ClassName Win32_ComputerSystem
if ($cs.PartOfDomain) {
    throw "This computer is already joined to domain '$($cs.Domain)'. Unjoin first if you need to re-join a different domain."
}

if (-not $Credential) {
    $Credential = Get-Credential -Message "Domain credential with rights to join computers to $DomainName"
}

$addComputerParams = @{
    DomainName = $DomainName
    Credential = $Credential
    Force      = $true
    Restart    = -not $NoRestart
}
if ($NewName -and $NewName -ne $env:COMPUTERNAME) {
    $addComputerParams.NewName = $NewName
}
if ($OuPath) {
    $addComputerParams.OUPath = $OuPath
}

if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Rename to '$NewName' and join domain '$DomainName'")) {
    Write-Host "Joining '$DomainName'$(if ($NewName) { " as '$NewName'" })..." -ForegroundColor Cyan
    Add-Computer @addComputerParams

    if ($NoRestart) {
        Write-Host "Join complete. A reboot is required before the change takes effect." -ForegroundColor Yellow
    }
    else {
        Write-Host "Join complete. Restarting..." -ForegroundColor Green
    }
}
