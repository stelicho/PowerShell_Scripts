<#
.SYNOPSIS
    Creates a DNS resource record (A, CNAME, or PTR) in an AD-integrated DNS zone.

.DESCRIPTION
    Rough-draft wrapper around the DnsServer module for quickly adding host
    records when standing up new servers/services, without having to open
    DNS Manager. Supports A records (with optional matching PTR record),
    standalone PTR records, and CNAME aliases.

.PARAMETER ZoneName
    Forward lookup zone to create the record in, e.g. "corp.contoso.com".

.PARAMETER RecordType
    Type of record to create: A, CNAME, or PTR.

.PARAMETER Name
    Host name (for A/CNAME) or the name portion of the record.

.PARAMETER IPv4Address
    Required for A and PTR records. The IP address to point the record at
    (or to derive the reverse zone/name from, for PTR).

.PARAMETER CreatePtr
    For A records, also create the matching reverse-lookup PTR record
    (requires the reverse zone to already exist).

.PARAMETER HostNameAlias
    Required for CNAME records. The FQDN the alias points to.

.PARAMETER ComputerName
    DNS server to create the record on. Defaults to the local machine.

.EXAMPLE
    .\New-DnsRecord.ps1 -ZoneName corp.contoso.com -RecordType A -Name fileserver01 -IPv4Address 10.10.1.50 -CreatePtr

.EXAMPLE
    .\New-DnsRecord.ps1 -ZoneName corp.contoso.com -RecordType CNAME -Name intranet -HostNameAlias webserver01.corp.contoso.com
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$ZoneName,

    [Parameter(Mandatory)]
    [ValidateSet('A', 'CNAME', 'PTR')]
    [string]$RecordType,

    [Parameter(Mandatory)]
    [string]$Name,

    [string]$IPv4Address,
    [switch]$CreatePtr,
    [string]$HostNameAlias,

    [string]$ComputerName = $env:COMPUTERNAME
)

$ErrorActionPreference = 'Stop'
Import-Module DnsServer

switch ($RecordType) {
    'A' {
        if (-not $IPv4Address) { throw "-IPv4Address is required for A records." }

        if ($PSCmdlet.ShouldProcess("$Name.$ZoneName", "Create A record -> $IPv4Address")) {
            Add-DnsServerResourceRecordA -ZoneName $ZoneName -Name $Name -IPv4Address $IPv4Address -ComputerName $ComputerName -CreatePtr:$CreatePtr
            Write-Host "Created A record: $Name.$ZoneName -> $IPv4Address$(if ($CreatePtr) { ' (with PTR)' })" -ForegroundColor Green
        }
    }
    'CNAME' {
        if (-not $HostNameAlias) { throw "-HostNameAlias is required for CNAME records." }

        if ($PSCmdlet.ShouldProcess("$Name.$ZoneName", "Create CNAME record -> $HostNameAlias")) {
            Add-DnsServerResourceRecordCName -ZoneName $ZoneName -Name $Name -HostNameAlias $HostNameAlias -ComputerName $ComputerName
            Write-Host "Created CNAME record: $Name.$ZoneName -> $HostNameAlias" -ForegroundColor Green
        }
    }
    'PTR' {
        if (-not $IPv4Address) { throw "-IPv4Address is required to derive the PTR record name." }

        $octets = $IPv4Address -split '\.'
        $reverseZone = "$($octets[2]).$($octets[1]).$($octets[0]).in-addr.arpa"
        $ptrName = $octets[3]

        if ($PSCmdlet.ShouldProcess("$ptrName.$reverseZone", "Create PTR record -> $Name.$ZoneName")) {
            Add-DnsServerResourceRecordPtr -ZoneName $reverseZone -Name $ptrName -PtrDomainName "$Name.$ZoneName" -ComputerName $ComputerName
            Write-Host "Created PTR record: $ptrName.$reverseZone -> $Name.$ZoneName" -ForegroundColor Green
        }
    }
}
