<#
.SYNOPSIS
    Checks a Windows host against a handful of common CIS Benchmark controls and
    reports pass/fail, with optional automatic remediation.

.DESCRIPTION
    Starter/rough-draft benchmark checker, not a full CIS Benchmark implementation.
    Covers a representative sample of high-value controls so the check -> report ->
    optional remediate pattern can be extended with the rest of the relevant CIS
    benchmark document (Level 1 Windows Server or workstation baseline).

.PARAMETER Remediate
    If specified, automatically fixes any failed checks below instead of just reporting them.

.PARAMETER ReportPath
    Optional path to export the results as CSV.

.EXAMPLE
    .\Test-CisBenchmark.ps1

.EXAMPLE
    .\Test-CisBenchmark.ps1 -Remediate -ReportPath C:\Reports\cis-scan.csv
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Remediate,
    [string]$ReportPath
)

$results = @()

function Add-Result {
    param($Control, $Description, $Passed, $Remediation)
    $script:results += [PSCustomObject]@{
        Control     = $Control
        Description = $Description
        Passed      = $Passed
        Remediation = $Remediation
    }
}

# --- 1. SMBv1 protocol disabled (CIS 18.3.x) ---
$smb1 = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -ErrorAction SilentlyContinue
$smb1Disabled = -not $smb1 -or $smb1.State -eq 'Disabled'
Add-Result -Control '18.3.x' -Description 'SMBv1 protocol disabled' -Passed $smb1Disabled -Remediation {
    Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart
}

# --- 2. Guest account disabled (CIS 2.3.1.x) ---
$guest = Get-LocalUser -Name 'Guest' -ErrorAction SilentlyContinue
$guestDisabled = -not $guest -or -not $guest.Enabled
Add-Result -Control '2.3.1.x' -Description 'Guest account is disabled' -Passed $guestDisabled -Remediation {
    Disable-LocalUser -Name 'Guest' -ErrorAction SilentlyContinue
}

# --- 3. Windows Firewall enabled on all profiles (CIS 9.1-9.3) ---
$fwProfiles = Get-NetFirewallProfile
$fwEnabled = -not ($fwProfiles | Where-Object { -not $_.Enabled })
Add-Result -Control '9.1-9.3' -Description 'Windows Firewall enabled on all profiles' -Passed $fwEnabled -Remediation {
    Set-NetFirewallProfile -All -Enabled True
}

# --- 4. RDP requires Network Level Authentication (CIS 18.9.65.3) ---
$nlaPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp'
$nla = (Get-ItemProperty -Path $nlaPath -Name UserAuthentication -ErrorAction SilentlyContinue).UserAuthentication
Add-Result -Control '18.9.65.3' -Description 'RDP requires Network Level Authentication' -Passed ($nla -eq 1) -Remediation {
    Set-ItemProperty -Path $nlaPath -Name UserAuthentication -Value 1
}

# --- 5. Minimum password length >= 14 characters (CIS 1.1.4) ---
$secpolFile = Join-Path $env:TEMP 'secpol_export.cfg'
$null = secedit /export /cfg $secpolFile /quiet
$minPwLine = Get-Content $secpolFile | Where-Object { $_ -match '^MinimumPasswordLength' }
$minPwLength = if ($minPwLine) { [int]($minPwLine -split '=')[1].Trim() } else { 0 }
Remove-Item $secpolFile -ErrorAction SilentlyContinue
Add-Result -Control '1.1.4' -Description 'Minimum password length is at least 14 characters' -Passed ($minPwLength -ge 14) -Remediation {
    net accounts /minpwlen:14
}

# --- Report + optional remediation ---
foreach ($r in $results) {
    $status = if ($r.Passed) { 'PASS' } else { 'FAIL' }
    $color  = if ($r.Passed) { 'Green' } else { 'Red' }
    Write-Host "[$status] $($r.Control) - $($r.Description)" -ForegroundColor $color

    if (-not $r.Passed -and $Remediate -and $PSCmdlet.ShouldProcess($r.Control, 'Remediate')) {
        Write-Host "  Remediating..." -ForegroundColor Yellow
        & $r.Remediation
    }
}

if ($ReportPath) {
    $results | Select-Object Control, Description, Passed | Export-Csv -Path $ReportPath -NoTypeInformation
    Write-Host "Report exported to $ReportPath" -ForegroundColor Cyan
}
