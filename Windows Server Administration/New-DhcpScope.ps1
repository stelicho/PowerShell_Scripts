<#
.SYNOPSIS
    Creates a new DHCP scope with a standard set of options (gateway, DNS
    servers, lease duration) and activates it.

.DESCRIPTION
    Rough-draft DHCP provisioning script for the Windows DHCP Server role.
    Wraps Add-DhcpServerv4Scope and Set-DhcpServerv4OptionValue so a new
    subnet's scope, exclusion range, and common options can be created in
    one call instead of clicking through the DHCP console.

.PARAMETER ScopeName
    Friendly name for the scope, e.g. "VLAN 20 - Workstations".

.PARAMETER StartRange / EndRange
    Start and end IP addresses of the scope's address pool.

.PARAMETER SubnetMask
    Subnet mask for the scope, e.g. "255.255.255.0".

.PARAMETER Gateway
    Default gateway (router) option to hand out to clients.

.PARAMETER DnsServers
    DNS server IP(s) to hand out to clients.

.PARAMETER LeaseDurationDays
    Lease duration in days. Default: 8.

.PARAMETER ExclusionStart / ExclusionEnd
    Optional exclusion range within the scope (e.g. reserved for static/infrastructure IPs).

.PARAMETER DhcpServer
    DHCP server to create the scope on. Defaults to the local machine.

.EXAMPLE
    .\New-DhcpScope.ps1 -ScopeName "VLAN 20 - Workstations" -StartRange 10.20.0.50 -EndRange 10.20.0.250 `
        -SubnetMask 255.255.255.0 -Gateway 10.20.0.1 -DnsServers 10.10.1.10,10.10.1.11 `
        -ExclusionStart 10.20.0.50 -ExclusionEnd 10.20.0.99
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$ScopeName,

    [Parameter(Mandatory)]
    [string]$StartRange,

    [Parameter(Mandatory)]
    [string]$EndRange,

    [Parameter(Mandatory)]
    [string]$SubnetMask,

    [Parameter(Mandatory)]
    [string]$Gateway,

    [Parameter(Mandatory)]
    [string[]]$DnsServers,

    [int]$LeaseDurationDays = 8,

    [string]$ExclusionStart,
    [string]$ExclusionEnd,

    [string]$DhcpServer = $env:COMPUTERNAME
)

$ErrorActionPreference = 'Stop'
Import-Module DhcpServer

if ($PSCmdlet.ShouldProcess($ScopeName, "Create DHCP scope on $DhcpServer")) {
    $scope = Add-DhcpServerv4Scope -ComputerName $DhcpServer -Name $ScopeName -StartRange $StartRange -EndRange $EndRange `
        -SubnetMask $SubnetMask -LeaseDuration (New-TimeSpan -Days $LeaseDurationDays) -State Active -PassThru

    Set-DhcpServerv4OptionValue -ComputerName $DhcpServer -ScopeId $scope.ScopeId -Router $Gateway -DnsServer $DnsServers

    if ($ExclusionStart -and $ExclusionEnd) {
        Add-DhcpServerv4ExclusionRange -ComputerName $DhcpServer -ScopeId $scope.ScopeId -StartRange $ExclusionStart -EndRange $ExclusionEnd
        Write-Host "Added exclusion range $ExclusionStart - $ExclusionEnd." -ForegroundColor Green
    }

    Write-Host "Created and activated scope '$ScopeName' ($($scope.ScopeId)) on $DhcpServer." -ForegroundColor Green
}
