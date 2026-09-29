<#
.SYNOPSIS
    Enables BitLocker on a volume using TPM protection plus a recovery
    password, with an option to escrow the recovery key to Active Directory.

.DESCRIPTION
    Rough-draft endpoint encryption rollout script. Defaults to encrypting
    the OS volume (C:) with the TPM protector for transparent unlock at boot,
    adds a numerical recovery password protector as a fallback, and can back
    that recovery password up to the computer's AD object so helpdesk can
    retrieve it if a user is locked out.

.PARAMETER MountPoint
    Drive letter of the volume to encrypt. Default: C:.

.PARAMETER EncryptionMethod
    BitLocker encryption method/cipher strength. Default: XtsAes256.

.PARAMETER BackupToAD
    If specified, backs up the recovery password to the computer's AD object
    (requires the AD schema extension for BitLocker recovery info and rights
    to write ms-FVE-RecoveryPassword).

.PARAMETER RecoveryKeyExportPath
    Optional local/network path to also export the recovery password to, as
    a fallback. NOTE: this writes the recovery password in plain text -
    restrict access on that folder/share to helpdesk/security staff only.

.EXAMPLE
    .\Enable-BitLockerEncryption.ps1 -BackupToAD

.EXAMPLE
    .\Enable-BitLockerEncryption.ps1 -MountPoint D: -RecoveryKeyExportPath "\\fileserver\BitLockerKeys\"
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$MountPoint = 'C:',

    [ValidateSet('Aes128', 'Aes256', 'XtsAes128', 'XtsAes256')]
    [string]$EncryptionMethod = 'XtsAes256',

    [switch]$BackupToAD,

    [string]$RecoveryKeyExportPath
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

Import-Module BitLocker

$volume = Get-BitLockerVolume -MountPoint $MountPoint -ErrorAction SilentlyContinue
if (-not $volume) {
    throw "Volume $MountPoint was not found."
}

if ($volume.ProtectionStatus -eq 'On') {
    Write-Warning "$MountPoint is already BitLocker-protected. No changes made."
    return
}

$tpm = Get-Tpm
if (-not $tpm.TpmPresent -or -not $tpm.TpmReady) {
    Write-Warning "TPM is not present/ready on this device. Falling back to a recovery-password-only protector."
}

if ($PSCmdlet.ShouldProcess($MountPoint, "Enable BitLocker ($EncryptionMethod)")) {
    if ($tpm.TpmPresent -and $tpm.TpmReady) {
        Enable-BitLocker -MountPoint $MountPoint -EncryptionMethod $EncryptionMethod -TpmProtector -SkipHardwareTest -ErrorAction Stop
    }
    else {
        Enable-BitLocker -MountPoint $MountPoint -EncryptionMethod $EncryptionMethod -RecoveryPasswordProtector -SkipHardwareTest -ErrorAction Stop
    }

    # Always ensure a numerical recovery password protector exists as a fallback unlock method
    $existingRecovery = (Get-BitLockerVolume -MountPoint $MountPoint).KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }
    if (-not $existingRecovery) {
        Add-BitLockerKeyProtector -MountPoint $MountPoint -RecoveryPasswordProtector | Out-Null
    }

    $recoveryProtector = (Get-BitLockerVolume -MountPoint $MountPoint).KeyProtector |
        Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' } | Select-Object -First 1

    if ($BackupToAD) {
        try {
            Backup-BitLockerKeyProtector -MountPoint $MountPoint -KeyProtectorId $recoveryProtector.KeyProtectorId
            Write-Host "Recovery password backed up to Active Directory." -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to back up recovery key to AD: $($_.Exception.Message)"
        }
    }

    if ($RecoveryKeyExportPath) {
        if (-not (Test-Path $RecoveryKeyExportPath)) {
            New-Item -Path $RecoveryKeyExportPath -ItemType Directory -Force | Out-Null
        }
        $exportFile = Join-Path $RecoveryKeyExportPath "$env:COMPUTERNAME-$($MountPoint.TrimEnd(':'))-BitLockerRecovery.txt"
        "Computer: $env:COMPUTERNAME`nVolume: $MountPoint`nRecovery Password: $($recoveryProtector.RecoveryPassword)`nKey Protector ID: $($recoveryProtector.KeyProtectorId)" |
            Out-File -FilePath $exportFile -Encoding utf8
        Write-Host "Recovery password exported to $exportFile" -ForegroundColor Green
    }

    Resume-BitLocker -MountPoint $MountPoint -ErrorAction SilentlyContinue
    Write-Host "BitLocker encryption started on $MountPoint. Encryption will continue in the background." -ForegroundColor Green
    Write-Host "Check progress with: Get-BitLockerVolume -MountPoint $MountPoint | Select EncryptionPercentage" -ForegroundColor Cyan
}
