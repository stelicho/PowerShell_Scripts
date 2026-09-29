<#
.SYNOPSIS
    Performs a NIST 800-88-aligned logical sanitization ("Clear") of free
    space on a target volume and generates a wipe certificate for ITAD records.

.DESCRIPTION
    Rough-draft data sanitization tool built around Windows' built-in
    cipher.exe /w utility, which overwrites deleted/free space on a volume in
    three passes (zeros, ones, random data) - equivalent to a NIST SP 800-88
    Rev. 1 "Clear" operation for media being retired or redeployed.

    This intentionally does NOT perform a full destructive disk wipe (that
    requires booting outside Windows and is out of scope for a script running
    against a live OS volume). For full-disk "Purge"-level sanitization ahead
    of physical destruction/recycling, pair this with a dedicated boot-time
    tool as part of the full ITAD chain of custody, per NIST 800-88 / DoD
    5220.22-M practice.

.PARAMETER DriveLetter
    The drive letter of the volume to sanitize free space on, e.g. "D".

.PARAMETER AssetTag
    Optional asset tag/serial number to record in the wipe certificate for
    ITAD tracking (e.g. into Razor ERP / AssetTiger / AssetWasp).

.PARAMETER CertificatePath
    Where to write the wipe certificate text file. Defaults to a
    "wipe-certificates" folder in the current directory.

.EXAMPLE
    .\New-SecureDataWipe.ps1 -DriveLetter D -AssetTag "ASSET-00123" -Confirm
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z]$')]
    [string]$DriveLetter,

    [string]$AssetTag,

    [string]$CertificatePath = ".\wipe-certificates"
)

$ErrorActionPreference = 'Stop'
$DriveLetter = $DriveLetter.ToUpper()
$targetPath = "$DriveLetter`:\"

if (-not (Test-Path $targetPath)) {
    throw "Drive $DriveLetter`: was not found on this system."
}

Write-Warning "This will overwrite ALL free/deleted space on $DriveLetter`: with three passes (NIST 800-88 'Clear'). Existing files are not touched, but anything previously deleted becomes unrecoverable."

if ($PSCmdlet.ShouldProcess($targetPath, "Sanitize free space (cipher /w, 3-pass)")) {
    Write-Host "Starting sanitization of $DriveLetter`: ..." -ForegroundColor Cyan
    $startTime = Get-Date
    cipher /w:$targetPath
    $endTime = Get-Date

    if (-not (Test-Path $CertificatePath)) {
        New-Item -Path $CertificatePath -ItemType Directory | Out-Null
    }

    $certFile = Join-Path $CertificatePath "wipe-cert-$DriveLetter-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    @"
DATA SANITIZATION CERTIFICATE
==============================
Standard:        NIST SP 800-88 Rev. 1 - Clear (free space overwrite, 3-pass)
Host:            $env:COMPUTERNAME
Drive:           $DriveLetter`:
Asset Tag:       $AssetTag
Performed By:    $env:USERNAME
Start Time:      $startTime
End Time:        $endTime
Tool:            Windows cipher.exe /w
"@ | Out-File -FilePath $certFile -Encoding utf8

    Write-Host "Sanitization complete. Certificate written to $certFile" -ForegroundColor Green
}
