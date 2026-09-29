<#
.SYNOPSIS
    Creates a new IIS website (app pool + site + bindings) with a basic
    HTTP binding, and optionally imports a PFX certificate for HTTPS.

.DESCRIPTION
    Rough-draft IIS provisioning script. Creates a dedicated application
    pool, points a new site at a physical path, binds it to HTTP (and
    HTTPS if a certificate is supplied), and starts everything.

.PARAMETER SiteName
    Name of the new IIS site and application pool.

.PARAMETER PhysicalPath
    Filesystem path the site's content lives in. Created if it doesn't exist.

.PARAMETER HostHeader
    Host header (FQDN) to bind the site to, e.g. "intranet.corp.contoso.com".

.PARAMETER Port
    HTTP port to bind. Default: 80.

.PARAMETER CertificatePfxPath / CertificatePassword
    Optional PFX certificate to import into the local machine certificate
    store and bind to port 443 for HTTPS.

.EXAMPLE
    .\New-IisWebsite.ps1 -SiteName "Intranet" -PhysicalPath "D:\WebRoot\Intranet" -HostHeader "intranet.corp.contoso.com"

.EXAMPLE
    .\New-IisWebsite.ps1 -SiteName "Intranet" -PhysicalPath "D:\WebRoot\Intranet" -HostHeader "intranet.corp.contoso.com" `
        -CertificatePfxPath "C:\Certs\intranet.pfx"
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$SiteName,

    [Parameter(Mandatory)]
    [string]$PhysicalPath,

    [Parameter(Mandatory)]
    [string]$HostHeader,

    [int]$Port = 80,

    [string]$CertificatePfxPath,
    [System.Security.SecureString]$CertificatePassword
)

$ErrorActionPreference = 'Stop'
Import-Module WebAdministration

if (-not (Test-Path $PhysicalPath)) {
    New-Item -Path $PhysicalPath -ItemType Directory -Force | Out-Null
}

if ($PSCmdlet.ShouldProcess($SiteName, "Create IIS application pool and site")) {
    if (-not (Test-Path "IIS:\AppPools\$SiteName")) {
        New-WebAppPool -Name $SiteName | Out-Null
    }
    Set-ItemProperty -Path "IIS:\AppPools\$SiteName" -Name managedRuntimeVersion -Value 'v4.0'

    if (Get-Website -Name $SiteName -ErrorAction SilentlyContinue) {
        throw "A site named '$SiteName' already exists in IIS."
    }

    New-Website -Name $SiteName -PhysicalPath $PhysicalPath -ApplicationPool $SiteName -HostHeader $HostHeader -Port $Port | Out-Null
    Write-Host "Created site '$SiteName' bound to http://$HostHeader`:$Port" -ForegroundColor Green

    if ($CertificatePfxPath) {
        if (-not $CertificatePassword) {
            $CertificatePassword = Read-Host -Prompt "PFX password for $CertificatePfxPath" -AsSecureString
        }
        $cert = Import-PfxCertificate -FilePath $CertificatePfxPath -CertStoreLocation 'Cert:\LocalMachine\My' -Password $CertificatePassword

        New-WebBinding -Name $SiteName -Protocol https -Port 443 -HostHeader $HostHeader -SslFlags 1
        Get-WebBinding -Name $SiteName -Protocol https | ForEach-Object { $_.AddSslCertificate($cert.GetCertHashString(), 'my') }

        Write-Host "Bound HTTPS on port 443 using certificate thumbprint $($cert.Thumbprint)." -ForegroundColor Green
    }

    Start-WebAppPool -Name $SiteName
    Start-Website -Name $SiteName
    Write-Host "Site '$SiteName' started." -ForegroundColor Green
}
